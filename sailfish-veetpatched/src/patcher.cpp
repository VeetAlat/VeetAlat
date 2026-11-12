#include "patcher.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTextStream>

namespace {

QString readAll(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    return QString::fromUtf8(f.readAll());
}

// KEY="value" from a patch.conf.
QString confValue(const QString &conf, const QString &key)
{
    QRegularExpression re(QStringLiteral("^%1=\"(.*)\"\\s*$").arg(key), QRegularExpression::MultilineOption);
    const QRegularExpressionMatch m = re.match(conf);
    return m.hasMatch() ? m.captured(1) : QString();
}

} // namespace

Patcher::Patcher(QObject *parent)
    : QObject(parent),
      m_dataDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)),
      m_patchesDir(qEnvironmentVariableIsSet("VEETPATCHED_PATCHES")
                   ? QString::fromLocal8Bit(qgetenv("VEETPATCHED_PATCHES"))
                   : QStringLiteral("/usr/share/veetpatched/patches"))
{
    QDir().mkpath(m_dataDir);
    m_poll.setInterval(250);
    connect(&m_poll, &QTimer::timeout, this, &Patcher::poll);
    readPatches();
    // A request number that's new each start, so an old answer never counts.
    m_tag = int(QDateTime::currentMSecsSinceEpoch() % 1000000) * 10;
}

void Patcher::setDataDir(const QString &dir)
{
    if (dir == m_dataDir)
        return;
    m_dataDir = dir;
    QDir().mkpath(m_dataDir);
    emit dataDirChanged();
}

void Patcher::readPatches()
{
    QVariantList list;
    QDir dir(m_patchesDir);
    const QStringList ids = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString &id : ids) {
        const QString conf = readAll(dir.filePath(id + QStringLiteral("/patch.conf")));
        if (conf.isEmpty())
            continue;
        QVariantMap p;
        p.insert(QStringLiteral("id"), id);
        p.insert(QStringLiteral("name"), confValue(conf, QStringLiteral("NAME")));
        p.insert(QStringLiteral("description"), confValue(conf, QStringLiteral("DESCRIPTION")));
        p.insert(QStringLiteral("state"), QStringLiteral("unknown"));
        list.append(p);
    }
    m_patches = list;
    emit patchesChanged();
}

void Patcher::setBusy(bool busy)
{
    if (busy == m_busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

bool Patcher::request(const QString &action, const QString &id)
{
    if (m_busy)
        return false;
    m_action = action;
    ++m_tag;
    QFile f(m_dataDir + QStringLiteral("/request"));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        QVariantMap r;
        r.insert(QStringLiteral("ok"), false);
        r.insert(QStringLiteral("message"), QStringLiteral("The request couldn't be written to ") + f.fileName());
        m_lastResult = r;
        emit lastResultChanged();
        return false;
    }
    // Written and closed in one go: systemd's path unit starts the helper on close.
    f.write(QStringLiteral("%1 %2 %3\n").arg(action, id).arg(m_tag).toUtf8());
    f.close();
    m_sentAt = QDateTime::currentMSecsSinceEpoch();
    setBusy(true);
    m_poll.start();
    return true;
}

void Patcher::poll()
{
    const QString status = readAll(m_dataDir + QStringLiteral("/status"));
    const QStringList lines = status.split(QLatin1Char('\n'), QString::SkipEmptyParts);
    if (lines.isEmpty() || lines.first() != QStringLiteral("request %1").arg(m_tag)) {
        if (QDateTime::currentMSecsSinceEpoch() - m_sentAt > m_timeout) {
            m_poll.stop();
            setBusy(false);
            if (m_helperAnswers) {
                m_helperAnswers = false;
                emit helperAnswersChanged();
            }
            QVariantMap r;
            r.insert(QStringLiteral("ok"), false);
            r.insert(QStringLiteral("message"), QStringLiteral("VeetPatched's helper didn't answer. Restart the phone; if it still doesn't, reinstall VeetPatched."));
            m_lastResult = r;
            emit lastResultChanged();
            emit answered(m_action, r);
        }
        return;
    }
    m_poll.stop();

    // "result ID STATE [message]" and "patch ID STATE" lines.
    QVariantMap result;
    QMap<QString, QString> states;
    for (const QString &line : lines) {
        if (line.startsWith(QStringLiteral("result "))) {
            const QStringList parts = line.mid(7).split(QLatin1Char(' '));
            const QString state = parts.value(1);
            result.insert(QStringLiteral("patch"), parts.value(0));
            result.insert(QStringLiteral("state"), state);
            result.insert(QStringLiteral("message"), QStringList(parts.mid(2)).join(QLatin1Char(' ')));
            result.insert(QStringLiteral("ok"), state != QStringLiteral("failed"));
        } else if (line.startsWith(QStringLiteral("patch "))) {
            const QStringList parts = line.split(QLatin1Char(' '));
            states.insert(parts.value(1), parts.value(2));
        }
    }
    for (int i = 0; i < m_patches.size(); i++) {
        QVariantMap p = m_patches.at(i).toMap();
        if (states.contains(p.value(QStringLiteral("id")).toString()))
            p.insert(QStringLiteral("state"), states.value(p.value(QStringLiteral("id")).toString()));
        m_patches[i] = p;
    }
    emit patchesChanged();
    m_log = readAll(m_dataDir + QStringLiteral("/log"));
    emit logChanged();
    if (!m_helperAnswers) {
        m_helperAnswers = true;
        emit helperAnswersChanged();
    }
    m_lastResult = result;
    emit lastResultChanged();
    setBusy(false);
    emit answered(m_action, result);
}

#include "patcher.h"

#include <QDateTime>
#include <QFileInfo>
#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTextStream>

#include <algorithm>

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

const char *const VERSION = "0.2.2";
const qint64 APP_LOG_MAX = 131072;

// "2026-11-12 17:25:20 INFO  text" lines into entries.
void parseLog(const QString &text, const QString &source, QVariantList &into)
{
    static const QRegularExpression re(QStringLiteral("^(\\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d) (INFO|WARN|ERROR)\\s+(.*)$"));
    const QStringList lines = text.split(QLatin1Char('\n'), QString::SkipEmptyParts);
    for (const QString &line : lines) {
        const QRegularExpressionMatch m = re.match(line);
        if (!m.hasMatch())
            continue;
        QVariantMap e;
        e.insert(QStringLiteral("time"), m.captured(1));
        e.insert(QStringLiteral("level"), m.captured(2));
        e.insert(QStringLiteral("source"), source);
        e.insert(QStringLiteral("text"), m.captured(3));
        into.append(e);
    }
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
    QStringList ids;
    for (const QVariant &p : m_patches)
        ids << p.toMap().value(QStringLiteral("id")).toString();
    logApp(QStringLiteral("INFO"), QStringLiteral("VeetPatched %1 started; patches: %2")
           .arg(QLatin1String(VERSION), ids.isEmpty() ? QStringLiteral("none found in ") + m_patchesDir : ids.join(QStringLiteral(", "))));
}

void Patcher::logApp(const QString &level, const QString &text)
{
    const QString path = m_dataDir + QStringLiteral("/app.log");
    if (QFileInfo(path).size() > APP_LOG_MAX) {
        QFile::remove(path + QStringLiteral(".1"));
        QFile::rename(path, path + QStringLiteral(".1"));
    }
    {
        // Closed before it's read back, or the newest line is still in the buffer.
        QFile f(path);
        if (f.open(QIODevice::Append | QIODevice::Text)) {
            f.write(QStringLiteral("%1 %2 %3\n")
                    .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss")),
                         level.leftJustified(5), text).toUtf8());
        }
    }
    reloadLog();
}

void Patcher::reloadLog()
{
    QVariantList entries;
    parseLog(readAll(m_dataDir + QStringLiteral("/log")), QStringLiteral("helper"), entries);
    parseLog(readAll(m_dataDir + QStringLiteral("/app.log.1")) + readAll(m_dataDir + QStringLiteral("/app.log")),
             QStringLiteral("app"), entries);
    // In time order; entries in the same second keep their order.
    std::stable_sort(entries.begin(), entries.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("time")).toString() < b.toMap().value(QStringLiteral("time")).toString();
    });
    while (entries.size() > 400)
        entries.removeFirst();
    m_logEntries = entries;
    emit logChanged();
}

QString Patcher::log() const
{
    QString out;
    for (const QVariant &v : m_logEntries) {
        const QVariantMap e = v.toMap();
        out += QStringLiteral("%1 %2 [%3] %4\n").arg(e.value(QStringLiteral("time")).toString(),
                                                    e.value(QStringLiteral("level")).toString().leftJustified(5),
                                                    e.value(QStringLiteral("source")).toString(),
                                                    e.value(QStringLiteral("text")).toString());
    }
    return out;
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
        logApp(QStringLiteral("ERROR"), QStringLiteral("couldn't write the request to %1: %2").arg(f.fileName(), f.errorString()));
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
    logApp(QStringLiteral("INFO"), QStringLiteral("sent request #%1: %2 %3").arg(m_tag).arg(action, id));
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
            logApp(QStringLiteral("ERROR"), QStringLiteral("no answer to request #%1 after %2 s: the helper isn't running "
                                                           "(is veetpatched.path started?)").arg(m_tag).arg(m_timeout / 1000.0));
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
    const qint64 took = QDateTime::currentMSecsSinceEpoch() - m_sentAt;
    if (result.value(QStringLiteral("ok")).toBool()) {
        logApp(QStringLiteral("INFO"), QStringLiteral("request #%1 answered after %2 ms: %3 %4")
               .arg(m_tag).arg(took).arg(result.value(QStringLiteral("patch")).toString(), result.value(QStringLiteral("state")).toString()));
    } else {
        logApp(QStringLiteral("ERROR"), QStringLiteral("request #%1 failed after %2 ms: %3")
               .arg(m_tag).arg(took).arg(result.value(QStringLiteral("message")).toString()));
    }
    if (!m_helperAnswers) {
        m_helperAnswers = true;
        emit helperAnswersChanged();
    }
    m_lastResult = result;
    emit lastResultChanged();
    setBusy(false);
    emit answered(m_action, result);
}

#include "nrcontrol.h"

#include <QDebug>
#include <QFile>
#include <QFileInfo>

namespace {
const QString RunDir = QStringLiteral("/run/nr-mode");
const QString RequestFile = QStringLiteral("/run/nr-mode/request");
const QString StateFile = QStringLiteral("/run/nr-mode/state");
const QString LogFile = QStringLiteral("/run/nr-mode/log");
const QString DiagFile = QStringLiteral("/run/nr-mode/diag.txt");
const QString DropinDir = QStringLiteral("/etc/ofono/binder.d");
const QString DropinFile = QStringLiteral("/etc/ofono/binder.d/90-nr-mode.conf");

// The last maxLines lines of a text file, or an empty string.
QString readTail(const QString &path, int maxLines)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    QStringList lines = QString::fromUtf8(file.readAll()).trimmed().split(QLatin1Char('\n'));
    if (lines.size() > maxLines) {
        lines = lines.mid(lines.size() - maxLines);
    }
    return lines.join(QLatin1Char('\n'));
}
}

NrControl::NrControl(const QString &root, QObject *parent)
    : QObject(parent)
    , m_root(root)
{
    // The helper replaces files with rename(), which a file watch would
    // lose track of, so watch the directories instead.
    // The helper appends to its log in place, so that one is watched as a
    // file too.
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &NrControl::refresh);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &NrControl::refresh);
    refresh();
}

bool NrControl::request(const QString &mode)
{
    const bool diag = mode == QLatin1String("diag");
    if (mode != QLatin1String("on") && mode != QLatin1String("on-keep")
            && mode != QLatin1String("off") && !diag) {
        qWarning() << "Unknown NR mode request" << mode;
        return false;
    }

    QFile file(m_root + RequestFile);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "Cannot write" << file.fileName() << file.errorString();
        m_state = QStringLiteral("error: cannot reach the helper (%1)").arg(file.errorString());
        emit changed();
        return false;
    }
    file.write(mode.toLatin1() + '\n');
    file.close(); // the path unit fires on close

    if (diag) {
        // A report doesn't change the mode, so don't show "busy".
        return true;
    }

    // Show progress right away instead of waiting for the helper's first
    // state update.
    m_state = QStringLiteral("busy: starting");
    emit changed();
    return true;
}

void NrControl::refresh()
{
    watch();

    const bool enabled = QFileInfo::exists(m_root + DropinFile);
    QString state;
    QFile file(m_root + StateFile);
    if (file.open(QIODevice::ReadOnly)) {
        state = QString::fromUtf8(file.readLine(256)).trimmed();
    }

    // Keep our optimistic "busy: starting" until the helper has
    // something newer to say.
    if (state.isEmpty() && busy()) {
        state = m_state;
    }

    if (enabled != m_enabled || state != m_state) {
        m_enabled = enabled;
        m_state = state;
        emit changed();
    }

    const QString log = readTail(m_root + LogFile, 300);
    if (log != m_log) {
        m_log = log;
        emit logChanged();
    }

    const QString diagnostics = readTail(m_root + DiagFile, 1000);
    if (diagnostics != m_diagnostics) {
        m_diagnostics = diagnostics;
        emit diagnosticsChanged();
    }
}

void NrControl::watch()
{
    // binder.d may not exist until the helper creates it, so fall back
    // to watching its parent.
    const QStringList wanted {
        m_root + RunDir,
        QFileInfo::exists(m_root + DropinDir) ? m_root + DropinDir
                                              : m_root + QStringLiteral("/etc/ofono"),
    };
    for (const QString &dir : wanted) {
        if (!m_watcher.directories().contains(dir) && QFileInfo::exists(dir)) {
            m_watcher.addPath(dir);
        }
    }
    // Trimming the log replaces the file, which drops the watch; the
    // directory change that causes brings us back here to re-add it.
    const QString log = m_root + LogFile;
    if (!m_watcher.files().contains(log) && QFileInfo::exists(log)) {
        m_watcher.addPath(log);
    }
}

#include "nrcontrol.h"

#include <QDebug>
#include <QFile>
#include <QFileInfo>

namespace {
const QString RunDir = QStringLiteral("/run/nr-mode");
const QString RequestFile = QStringLiteral("/run/nr-mode/request");
const QString StateFile = QStringLiteral("/run/nr-mode/state");
const QString DropinDir = QStringLiteral("/etc/ofono/binder.d");
const QString DropinFile = QStringLiteral("/etc/ofono/binder.d/90-nr-mode.conf");
}

NrControl::NrControl(const QString &root, QObject *parent)
    : QObject(parent)
    , m_root(root)
{
    // The helper replaces files with rename(), which a file watch would
    // lose track of, so watch the directories instead.
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &NrControl::refresh);
    refresh();
}

bool NrControl::request(const QString &mode)
{
    if (mode != QLatin1String("on") && mode != QLatin1String("on-keep")
            && mode != QLatin1String("off")) {
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
}

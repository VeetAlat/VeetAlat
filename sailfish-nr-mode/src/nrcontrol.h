#ifndef NRCONTROL_H
#define NRCONTROL_H

#include <QFileSystemWatcher>
#include <QObject>
#include <QString>

// Talks to the root helper (helper/nr-mode-helper) through two files:
// the app writes a request into /run/nr-mode/request, a systemd path unit
// notices and runs the helper, and the helper reports progress in
// /run/nr-mode/state. Whether NR-only is active is read straight from the
// ofono config drop-in the helper maintains. The helper's step-by-step log
// and its latest diagnostics report are exposed as plain text.
class NrControl : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString log READ log NOTIFY logChanged)
    Q_PROPERTY(QString diagnostics READ diagnostics NOTIFY diagnosticsChanged)

public:
    // root is prepended to every path, for tests.
    explicit NrControl(const QString &root = QString(), QObject *parent = nullptr);

    bool enabled() const { return m_enabled; }
    bool busy() const { return m_state.startsWith(QLatin1String("busy")); }
    QString state() const { return m_state; }
    QString log() const { return m_log; }
    QString diagnostics() const { return m_diagnostics; }

    // mode is "on" (revert after 60 s without registration), "on-60",
    // "on-180", "on-300", "on-keep" (no automatic revert), "off", or
    // "diag" to have the helper write a fresh diagnostics report.
    Q_INVOKABLE bool request(const QString &mode);

signals:
    void changed();
    void logChanged();
    void diagnosticsChanged();

private slots:
    void refresh();

private:
    void watch();

    const QString m_root;
    QFileSystemWatcher m_watcher;
    bool m_enabled = false;
    QString m_state;
    QString m_log;
    QString m_diagnostics;
};

#endif // NRCONTROL_H

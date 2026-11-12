#ifndef PATCHER_H
#define PATCHER_H

#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantList>

// The app's side of VeetPatched. It can't change system files itself (it
// runs as the user, sandboxed): it writes a one-line request, like
// "apply statusbar 17", to its data folder; systemd's veetpatched.path
// starts the root helper, which does it and writes back "status" (the
// request's number, the result, and every patch's state) and "log".
class Patcher : public QObject
{
    Q_OBJECT
    // [{ id, name, description, state }], state: "applied", "not-applied",
    // "missing" (the file it changes isn't there) or "unknown".
    Q_PROPERTY(QVariantList patches READ patches NOTIFY patchesChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    // The last answer: { patch, state, message, ok }.
    Q_PROPERTY(QVariantMap lastResult READ lastResult NOTIFY lastResultChanged)
    Q_PROPERTY(QString log READ log NOTIFY logChanged)
    // The helper's log and the app's, merged in time order, newest last:
    // [{ time, level, source, text }], level "INFO", "WARN" or "ERROR",
    // source "helper" (root) or "app".
    Q_PROPERTY(QVariantList logEntries READ logEntries NOTIFY logChanged)
    // False when the helper didn't answer in time.
    Q_PROPERTY(bool helperAnswers READ helperAnswers NOTIFY helperAnswersChanged)
    Q_PROPERTY(QString dataDir READ dataDir WRITE setDataDir NOTIFY dataDirChanged)
    Q_PROPERTY(int timeout MEMBER m_timeout NOTIFY timeoutChanged)

public:
    explicit Patcher(QObject *parent = nullptr);

    QVariantList patches() const { return m_patches; }
    bool busy() const { return m_busy; }
    QVariantMap lastResult() const { return m_lastResult; }
    // Both logs as text, for copying.
    QString log() const;
    QVariantList logEntries() const { return m_logEntries; }
    bool helperAnswers() const { return m_helperAnswers; }
    QString dataDir() const { return m_dataDir; }
    void setDataDir(const QString &dir);

    Q_INVOKABLE bool apply(const QString &id) { return request(QStringLiteral("apply"), id); }
    Q_INVOKABLE bool unapply(const QString &id) { return request(QStringLiteral("unapply"), id); }
    Q_INVOKABLE bool refresh() { return request(QStringLiteral("status"), QStringLiteral("-")); }
    Q_INVOKABLE bool restartHome() { return request(QStringLiteral("restart-home"), QStringLiteral("-")); }
    // Re-reads both logs (the app's is written as things happen).
    Q_INVOKABLE void reloadLog();

signals:
    void patchesChanged();
    void busyChanged();
    void lastResultChanged();
    void logChanged();
    void helperAnswersChanged();
    void dataDirChanged();
    void timeoutChanged();
    void answered(const QString &action, const QVariantMap &result);

private:
    bool request(const QString &action, const QString &id);
    void poll();
    void readPatches();
    void setBusy(bool busy);
    void logApp(const QString &level, const QString &text);

    QVariantList m_patches;
    bool m_busy = false;
    QVariantMap m_lastResult;
    QVariantList m_logEntries;
    bool m_helperAnswers = true;
    QString m_dataDir;
    QString m_patchesDir;
    QString m_action;
    int m_tag = 0;
    int m_timeout = 15000;
    qint64 m_sentAt = 0;
    QTimer m_poll;
};

#endif

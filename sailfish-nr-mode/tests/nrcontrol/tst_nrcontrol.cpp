#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

#include "nrcontrol.h"

class TestNrControl : public QObject
{
    Q_OBJECT

private:
    static void write(const QString &path, const QByteArray &data)
    {
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
        f.write(data);
    }

private slots:
    void readsInitialState()
    {
        QTemporaryDir root;
        QDir(root.path()).mkpath("run/nr-mode");
        QDir(root.path()).mkpath("etc/ofono/binder.d");
        write(root.path() + "/run/nr-mode/state", "on\n");
        write(root.path() + "/etc/ofono/binder.d/90-nr-mode.conf", "[Settings]\n");

        NrControl control(root.path());
        QVERIFY(control.enabled());
        QVERIFY(!control.busy());
        QCOMPARE(control.state(), QStringLiteral("on"));
    }

    void writesRequestAndGoesBusy()
    {
        QTemporaryDir root;
        QDir(root.path()).mkpath("run/nr-mode");
        NrControl control(root.path());
        QVERIFY(!control.enabled());

        QVERIFY(control.request("on-keep"));
        QVERIFY(control.busy());
        QFile f(root.path() + "/run/nr-mode/request");
        QVERIFY(f.open(QIODevice::ReadOnly));
        QCOMPARE(f.readAll(), QByteArray("on-keep\n"));
    }

    void diagRequestDoesNotGoBusy()
    {
        QTemporaryDir root;
        QDir(root.path()).mkpath("run/nr-mode");
        NrControl control(root.path());
        QVERIFY(control.request("diag"));
        QVERIFY(!control.busy());
        QFile f(root.path() + "/run/nr-mode/request");
        QVERIFY(f.open(QIODevice::ReadOnly));
        QCOMPARE(f.readAll(), QByteArray("diag\n"));
    }

    void followsLogAppendsAndRotation()
    {
        QTemporaryDir root;
        QDir(root.path()).mkpath("run/nr-mode");
        const QString log = root.path() + "/run/nr-mode/log";
        write(log, "10:00:00 first\n");
        NrControl control(root.path());
        QCOMPARE(control.log(), QStringLiteral("10:00:00 first"));

        // Helper style append.
        {
            QFile f(log);
            QVERIFY(f.open(QIODevice::Append));
            f.write("10:00:01 second\n");
        }
        QTRY_VERIFY(control.log().endsWith("10:00:01 second"));

        // Helper style trim: replace the file, then keep appending.
        write(log + ".tmp", "10:00:02 trimmed\n");
        QFile::remove(log);
        QFile::rename(log + ".tmp", log);
        QTRY_COMPARE(control.log(), QStringLiteral("10:00:02 trimmed"));
        {
            QFile f(log);
            QVERIFY(f.open(QIODevice::Append));
            f.write("10:00:03 after trim\n");
        }
        QTRY_VERIFY(control.log().endsWith("10:00:03 after trim"));
    }

    void logShowsOnlyTheTail()
    {
        QTemporaryDir root;
        QDir(root.path()).mkpath("run/nr-mode");
        QByteArray lines;
        for (int i = 0; i < 500; i++) {
            lines += QByteArray::number(i) + '\n';
        }
        write(root.path() + "/run/nr-mode/log", lines);
        NrControl control(root.path());
        QCOMPARE(control.log().split('\n').size(), 300);
        QVERIFY(control.log().endsWith("499"));
    }

    void readsDiagnostics()
    {
        QTemporaryDir root;
        QDir(root.path()).mkpath("run/nr-mode");
        NrControl control(root.path());
        QVERIFY(control.diagnostics().isEmpty());
        write(root.path() + "/run/nr-mode/diag.txt.tmp", "NR Mode diagnostics\n== SIM\n");
        QFile::rename(root.path() + "/run/nr-mode/diag.txt.tmp", root.path() + "/run/nr-mode/diag.txt");
        QTRY_VERIFY(control.diagnostics().startsWith("NR Mode diagnostics"));
    }

    void rejectsUnknownRequests()
    {
        QTemporaryDir root;
        QDir(root.path()).mkpath("run/nr-mode");
        NrControl control(root.path());
        QVERIFY(!control.request("rm -rf /"));
        QVERIFY(!QFile::exists(root.path() + "/run/nr-mode/request"));
    }

    void reportsMissingHelper()
    {
        QTemporaryDir root; // no run/nr-mode: helper not installed
        NrControl control(root.path());
        QVERIFY(!control.request("on"));
        QVERIFY(control.state().startsWith("error"));
    }

    void followsHelperUpdates()
    {
        QTemporaryDir root;
        QDir(root.path()).mkpath("run/nr-mode");
        QDir(root.path()).mkpath("etc/ofono");
        NrControl control(root.path());
        QSignalSpy spy(&control, &NrControl::changed);

        // Helper style: write a temp file and rename it into place.
        write(root.path() + "/run/nr-mode/state.tmp", "busy: switching\n");
        QFile::rename(root.path() + "/run/nr-mode/state.tmp", root.path() + "/run/nr-mode/state");
        QTRY_VERIFY(control.busy());

        QDir(root.path()).mkpath("etc/ofono/binder.d");
        write(root.path() + "/etc/ofono/binder.d/90-nr-mode.conf", "[Settings]\n");
        write(root.path() + "/run/nr-mode/state.tmp", "on\n");
        QFile::remove(root.path() + "/run/nr-mode/state");
        QFile::rename(root.path() + "/run/nr-mode/state.tmp", root.path() + "/run/nr-mode/state");
        QTRY_VERIFY(control.enabled());
        QTRY_COMPARE(control.state(), QStringLiteral("on"));
        QVERIFY(spy.count() >= 2);
    }
};

QTEST_GUILESS_MAIN(TestNrControl)
#include "tst_nrcontrol.moc"

#include <QDir>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickView>
#include <QScopedPointer>
#include <QStandardPaths>

#include <sailfishapp.h>

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    // Must match OrganizationName/ApplicationName in the desktop file:
    // Sailjail only lets the app write ~/.local/share/<org>/<app>.
    app->setOrganizationName(QStringLiteral("org.veetalat"));
    app->setApplicationName(QStringLiteral("yleisuutiset"));

    QScopedPointer<QQuickView> view(SailfishApp::createView());

    // The feed cache lives in the app's own data directory.
    const QString storage = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
            + QStringLiteral("/QML/OfflineStorage");
    QDir().mkpath(storage);
    view->engine()->setOfflineStoragePath(storage);

    // Test hooks, unused in normal runs: YLEISUUTISET_FEED_BASE points the app at
    // local fixture feeds, YLEISUUTISET_NO_WINDOW runs it without showing a window
    // (the SDK has no GPU) so its event loop can still fetch.
    view->rootContext()->setContextProperty(QStringLiteral("feedBaseOverride"),
                                            QString::fromLocal8Bit(qgetenv("YLEISUUTISET_FEED_BASE")));

    view->setSource(SailfishApp::pathToMainQml());
    if (!qEnvironmentVariableIsSet("YLEISUUTISET_NO_WINDOW")) {
        view->show();
    }

    return app->exec();
}

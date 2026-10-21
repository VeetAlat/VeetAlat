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
    app->setApplicationName(QStringLiteral("ylefish"));

    QScopedPointer<QQuickView> view(SailfishApp::createView());

    // The feed cache lives in the app's own data directory.
    const QString storage = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
            + QStringLiteral("/QML/OfflineStorage");
    QDir().mkpath(storage);
    view->engine()->setOfflineStoragePath(storage);

    // Test hooks, unused in normal runs: YLEFISH_FEED_BASE points the app at
    // local fixture feeds (and YLEFISH_ARTICLE_BASE at local story pages),
    // YLEFISH_NO_WINDOW runs it without showing a window
    // (the SDK has no GPU) so its event loop can still fetch.
    view->rootContext()->setContextProperty(QStringLiteral("feedBaseOverride"),
                                            QString::fromLocal8Bit(qgetenv("YLEFISH_FEED_BASE")));
    // YLEFISH_ARTICLE_BASE fetches the stories from there instead of yle.fi.
    view->rootContext()->setContextProperty(QStringLiteral("articleBaseOverride"),
                                            QString::fromLocal8Bit(qgetenv("YLEFISH_ARTICLE_BASE")));

    view->setSource(SailfishApp::pathToMainQml());
    if (!qEnvironmentVariableIsSet("YLEFISH_NO_WINDOW")) {
        view->show();
    }

    return app->exec();
}

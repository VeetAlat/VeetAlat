#include <QDir>
#include <QGuiApplication>
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
    app->setApplicationName(QStringLiteral("bmitracker"));

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    // The LocalStorage database lives in the app's own data directory.
    // Create it up front rather than rely on anything else doing so.
    const QString storage = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
            + QStringLiteral("/QML/OfflineStorage");
    QDir().mkpath(storage);
    view->engine()->setOfflineStoragePath(storage);
    view->setSource(SailfishApp::pathToMainQml());
    view->show();

    return app->exec();
}

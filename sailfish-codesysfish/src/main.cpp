#include <QDir>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickView>
#include <QScopedPointer>
#include <QStandardPaths>

#include <sailfishapp.h>

#include "sthighlighter.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    // Must match OrganizationName/ApplicationName in the desktop file:
    // Sailjail only lets the app write ~/.local/share/<org>/<app>.
    app->setOrganizationName(QStringLiteral("org.veetalat"));
    app->setApplicationName(QStringLiteral("codesysfish"));

    qmlRegisterType<StHighlighter>("CodeSysFish", 1, 0, "StHighlighter");

    QScopedPointer<QQuickView> view(SailfishApp::createView());

    // The projects live in the app's own data directory.
    const QString storage = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
            + QStringLiteral("/QML/OfflineStorage");
    QDir().mkpath(storage);
    view->engine()->setOfflineStoragePath(storage);

    view->setSource(SailfishApp::pathToMainQml());
    // Test hook, unused in normal runs: CODESYSFISH_NO_WINDOW runs the app
    // without showing a window (the SDK has no GPU).
    if (!qEnvironmentVariableIsSet("CODESYSFISH_NO_WINDOW")) {
        view->show();
    }

    return app->exec();
}

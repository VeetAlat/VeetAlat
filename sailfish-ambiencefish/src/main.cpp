#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickView>
#include <QScopedPointer>

#include <sailfishapp.h>

#include "composer.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    // Must match OrganizationName/ApplicationName in the desktop file:
    // Sailjail only lets the app write ~/.local/share/<org>/<app> (and its cache).
    app->setOrganizationName(QStringLiteral("org.veetalat"));
    app->setApplicationName(QStringLiteral("ambiencefish"));

    qmlRegisterType<Composer>("AmbienceFish", 1, 0, "Composer");

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    // Test hooks, unused in normal runs: AMBIENCEFISH_FIXTURES points the
    // tests at their photos, AMBIENCEFISH_NO_WINDOW runs without a window
    // (the SDK has no GPU).
    view->rootContext()->setContextProperty(QStringLiteral("fixturesDir"),
                                            QString::fromLocal8Bit(qgetenv("AMBIENCEFISH_FIXTURES")));
    view->setSource(SailfishApp::pathToMainQml());
    if (!qEnvironmentVariableIsSet("AMBIENCEFISH_NO_WINDOW"))
        view->show();
    return app->exec();
}

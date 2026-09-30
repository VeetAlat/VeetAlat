#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QScopedPointer>
#include <QtQml>

#include <sailfishapp.h>

#include "game.h"
#include "tunnelview.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    // Must match OrganizationName/ApplicationName in the desktop file:
    // Sailjail only lets the app write ~/.local/share/<org>/<app>.
    app->setOrganizationName(QStringLiteral("org.veetalat"));
    app->setApplicationName(QStringLiteral("roachrider"));

    qmlRegisterUncreatableType<Game>("RoachRider", 1, 0, "Game",
                                     QStringLiteral("The game is gameEngine"));
    qmlRegisterType<TunnelView>("RoachRider", 1, 0, "TunnelView");

    Game game;
    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->rootContext()->setContextProperty(QStringLiteral("gameEngine"), &game);
    view->setSource(SailfishApp::pathToMainQml());
    view->show();

    return app->exec();
}

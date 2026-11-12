#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QScopedPointer>

#include <sailfishapp.h>

#include "patcher.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    // Must match the desktop file (Sailjail) and the helper's folder:
    // ~/.local/share/org.veetalat/veetpatched.
    app->setOrganizationName(QStringLiteral("org.veetalat"));
    app->setApplicationName(QStringLiteral("veetpatched"));

    qmlRegisterType<Patcher>("VeetPatched", 1, 0, "Patcher");

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->setSource(SailfishApp::pathToMainQml());
    // Test hook: VEETPATCHED_NO_WINDOW runs it without a window (the SDK has no GPU).
    if (!qEnvironmentVariableIsSet("VEETPATCHED_NO_WINDOW"))
        view->show();
    return app->exec();
}

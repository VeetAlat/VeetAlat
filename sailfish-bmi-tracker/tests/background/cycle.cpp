// Mimics Sailfish sending an app to the background and back: renders a QML
// file with a non-persistent GL context and scene graph (so hiding frees
// them, as on the phone), grabs it, hides, shows again, grabs again.
// Usage: cycle <import-path> <file.qml> <before.png> <after.png>
#include <QGuiApplication>
#include <QImage>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickView>
#include <QTimer>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QQuickView view;
    view.setPersistentOpenGLContext(false);
    view.setPersistentSceneGraph(false);
    view.engine()->addImportPath(argv[1]);
    view.setSource(QUrl::fromLocalFile(argv[2]));
    view.show();

    auto paints = [&] { return view.rootObject()->property("paints").toInt(); };
    QTimer::singleShot(1000, [&] {
        view.grabWindow().save(argv[3]);
        qWarning("before: paints=%d", paints());
        view.hide();          // home screen: GL context and scene graph released
        QTimer::singleShot(500, [&] {
            view.show();      // back to the app
            QTimer::singleShot(1000, [&] {
                view.grabWindow().save(argv[4]);
                qWarning("after: paints=%d", paints());
                app.quit();
            });
        });
    });
    return app.exec();
}

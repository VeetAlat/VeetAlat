// Draws the game in a few set situations and saves each as a PNG.
// Usage: render <output-dir> [width height]

#include <QDir>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QImage>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickView>
#include <QTemporaryDir>
#include <QTimer>
#include <functional>

#include "../../src/game.h"
#include "../../src/tunnelview.h"
#include "../bot.h"

namespace {

const char *Scene = R"(
import QtQuick 2.0
import RoachRider 1.0
Rectangle {
    gradient: Gradient {
        GradientStop { position: 0; color: "#05010f" }
        GradientStop { position: 0.45; color: "#170530" }
        GradientStop { position: 1; color: "#05010f" }
    }
    TunnelView { anchors.fill: parent; game: gameEngine; bikeSource: bikePicture }
}
)";

std::vector<std::string> track(std::initializer_list<std::pair<int, std::string>> rows)
{
    std::vector<std::string> t(80, "............");
    for (const auto &r : rows)
        t[r.first] = r.second;
    return t;
}

void ride(GameCore &g, double seconds)
{
    for (double t = 0; t < seconds; t += 1.0 / 60)
        g.step(1.0 / 60);
}

}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    const QString out = QString::fromLocal8Bit(argv[1]);
    const int w = argc > 3 ? atoi(argv[2]) : 540, h = argc > 3 ? atoi(argv[3]) : 1000;
    QDir().mkpath(out);
    QTemporaryDir settings;

    qmlRegisterUncreatableType<Game>("RoachRider", 1, 0, "Game", "no");
    qmlRegisterType<TunnelView>("RoachRider", 1, 0, "TunnelView");
    Game game(settings.filePath("s.ini"));
    QQuickView view;
    view.rootContext()->setContextProperty("gameEngine", &game);
    view.rootContext()->setContextProperty("bikePicture", QUrl::fromLocalFile(QStringLiteral(SRC_DIR "/qml/images/roach-back.png")));
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    QTemporaryDir qmlDir;
    QFile f(qmlDir.filePath("scene.qml"));
    f.open(QIODevice::WriteOnly);
    f.write(Scene);
    f.close();
    view.setSource(QUrl::fromLocalFile(f.fileName()));
    view.resize(w, h);
    view.show();

    // Wait for the window to be on screen before drawing into it.
    QElapsedTimer waited;
    waited.start();
    while (!view.isExposed() && waited.elapsed() < 5000)
        app.processEvents(QEventLoop::AllEvents, 50);

    auto shot = [&](const QString &name, std::function<void(GameCore &)> setup) {
        GameCore &g = game.core();
        setup(g);
        emit game.frame();
        QImage img = view.grabWindow();
        qInfo("%s: %s", qPrintable(name), img.save(out + "/" + name + ".png") ? "saved" : "FAILED");
    };

    shot("1-start", [](GameCore &g) { g.reset(1); });
    shot("2-riding", [](GameCore &g) {
        g.reset(4);
        Bot::play(g, 150);
    });
    shot("3-blocks", [](GameCore &g) {
        g.setTrack(track({ { 9, ".#..#...#..." }, { 16, "#..###..#.#." }, { 22, "      ......" }, { 23, "      ......" } }));
        ride(g, 0.2);
    });
    shot("4-jump", [](GameCore &g) {
        g.setTrack(track({ { 8, "            " }, { 9, "            " } }));
        ride(g, 0.5);
        g.jump();
        ride(g, 0.15);
    });
    shot("5-corner", [](GameCore &g) {
        g.setTrack(track({ { 10, "   ........." }, { 11, "   ........." }, { 12, "   ........." }, { 13, "   ........." } }));
        g.right();
        ride(g, 0.13);
    });
    shot("6-wall", [](GameCore &g) {
        g.setTrack(track({ { 12, "   .#......." }, { 13, "   ........." }, { 14, "   ........." }, { 15, "   ........." }, { 16, "   ........." } }));
        g.right();
        g.right();
        ride(g, 0.6);
    });
    shot("7-far", [](GameCore &g) { g.reset(9); Bot::play(g, 400); });
    shot("8-blocks-ahead", [](GameCore &g) { g.reset(2); Bot::play(g, 900); });
    shot("9-roof", [](GameCore &g) { g.reset(1); g.target = 7; g.pos = 7.5; g.camFace = 2; ride(g, 1); });
    return 0;
}

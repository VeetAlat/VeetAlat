// Tests the game rules and the track, on the build machine's Qt.
// Run: tests/run-tests.sh

#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

#include "../../src/game.h"
#include "../../src/gamecore.h"
#include "../bot.h"

namespace {

const std::string Plain = "............";
const std::string Gone = "            ";

std::vector<std::string> track(std::initializer_list<std::pair<int, std::string>> rows, int length = 40)
{
    std::vector<std::string> t(length, Plain);
    for (const auto &r : rows)
        t[r.first] = r.second;
    return t;
}

// Rides until the bike reaches `row` or the game ends.
void rideTo(GameCore &g, double row)
{
    for (int i = 0; i < 6000 && g.status == GameCore::Running && g.dist < row; ++i)
        g.step(1.0 / 60);
}

}

class TestGame : public QObject
{
    Q_OBJECT

private slots:
    void startsOnTheFloor()
    {
        GameCore g;
        g.reset(7);
        QCOMPARE(g.lane(), 1);
        QCOMPARE(g.status, GameCore::Running);
        QVERIFY(g.onGround());
        QCOMPARE(g.score(), 0);
    }

    void startIsPlainGrid()
    {
        for (unsigned seed = 1; seed < 20; ++seed) {
            GameCore g;
            g.reset(seed);
            for (int r = 0; r < Tuning::SafeStart; ++r)
                for (int l = 0; l < GameCore::Lanes; ++l)
                    QCOMPARE(g.cell(r, l), GameCore::Tile);
        }
    }

    void lanesGoAllTheWayRound()
    {
        GameCore g;
        g.reset(1);
        g.left();
        g.left();
        QCOMPARE(g.lane(), 11);   // off the left edge of the floor, up the left wall
        for (int i = 0; i < 12; ++i)
            g.right();
        QCOMPARE(g.lane(), 11);
    }

    void ridingUpTheWallTurnsTheView()
    {
        GameCore g;
        g.reset(1);
        g.right();
        g.right();
        rideTo(g, 12);
        QCOMPARE(g.lane(), 3);
        QCOMPARE(g.pos, 3.5);
        QVERIFY(std::fabs(g.camFace - 1) < 0.01);
        QCOMPARE(g.status, GameCore::Running);
    }

    void sidesTurnSmoothly()
    {
        for (double p = -6; p < 18; p += 0.01)
            QVERIFY(std::fabs(GameCore::faceValue(p + 0.01) - GameCore::faceValue(p)) < 0.0101);
        QCOMPARE(GameCore::faceValue(1.5), 0.0);
        QCOMPARE(GameCore::faceValue(3.0), 0.5);
        QCOMPARE(GameCore::faceValue(4.5), 1.0);
        QCOMPARE(GameCore::faceValue(-1.5), -1.0);
    }

    void fallsIntoAHole()
    {
        GameCore g;
        g.setTrack(track({ { 8, Gone }, { 9, Gone }, { 10, Gone } }));
        rideTo(g, 30);
        QCOMPARE(g.status, GameCore::Fell);
        QVERIFY(g.dist > 8 && g.dist < 12);
    }

    void jumpsOverAGap()
    {
        GameCore g;
        g.setTrack(track({ { 8, Gone }, { 9, Gone } }));
        rideTo(g, 7);
        g.jump();
        rideTo(g, 30);
        QCOMPARE(g.status, GameCore::Running);
    }

    void holeOnlyInOtherLanes()
    {
        // The floor's gone but the right wall's still there.
        GameCore g;
        g.setTrack(track({ { 8, "   ........." }, { 9, "   ........." }, { 10, "   ........." } }));
        g.right();
        g.right();
        rideTo(g, 30);
        QCOMPARE(g.status, GameCore::Running);
        QCOMPARE(g.lane(), 3);
    }

    void crashesIntoABlock()
    {
        GameCore g;
        g.setTrack(track({ { 10, ".#.........." } }));
        rideTo(g, 30);
        QCOMPARE(g.status, GameCore::Crashed);
    }

    void jumpsOverABlock()
    {
        GameCore g;
        g.setTrack(track({ { 10, ".#.........." } }));
        rideTo(g, 8.5);
        g.jump();
        rideTo(g, 30);
        QCOMPARE(g.status, GameCore::Running);
    }

    void goesRoundABlock()
    {
        GameCore g;
        g.setTrack(track({ { 10, ".#.........." } }));
        g.left();
        rideTo(g, 30);
        QCOMPARE(g.status, GameCore::Running);
    }

    void jumpPressedJustBeforeLandingCounts()
    {
        GameCore g;
        g.setTrack(track({}));
        g.jump();
        while (!(g.vh < 0 && g.h < 0.5))
            g.step(1.0 / 60);   // nearly down again
        g.jump();
        QVERIFY(g.airborne);
        for (int i = 0; i < 12 && g.vh < 0; ++i)
            g.step(1.0 / 60);
        QVERIFY(g.airborne);
        QVERIFY(g.vh > 0);      // took off again
    }

    void noSteeringWhileFalling()
    {
        GameCore g;
        g.setTrack(track({ { 8, Gone }, { 9, Gone }, { 10, Gone } }));
        rideTo(g, 8.3);
        QVERIFY(g.falling);
        g.right();
        g.jump();
        QCOMPARE(g.lane(), 1);
        QVERIFY(!g.airborne);
    }

    void gapsAreJumpable()
    {
        // Every gap that goes all the way round is shorter than a jump.
        for (unsigned seed = 1; seed <= 20; ++seed) {
            GameCore g;
            g.reset(seed);
            int run = 0;
            for (int r = 0; r < 3000; ++r) {
                // The track is built as the bike rides; move it along.
                while (g.dist < r - 5)
                    g.dist += 1, g.step(0);
                bool all = true;
                for (int l = 0; l < GameCore::Lanes; ++l)
                    all = all && g.cell(r, l) == GameCore::Hole;
                run = all ? run + 1 : 0;
                QVERIFY2(run < GameCore::speedAt(r) * GameCore::airTime() - 1,
                         qPrintable(QString("seed %1 row %2: gap of %3").arg(seed).arg(r).arg(run)));
            }
        }
    }

    void trackCanBeRidden()
    {
        // A player with perfect reactions gets through a long way on many
        // different tracks, so there's always a way through.
        for (unsigned seed = 1; seed <= 12; ++seed) {
            GameCore g;
            g.reset(seed);
            const int reached = Bot::play(g, 2500);
            QVERIFY2(reached >= 2500, qPrintable(QString("seed %1: stuck at row %2 (%3)")
                                                 .arg(seed).arg(reached)
                                                 .arg(g.status == GameCore::Fell ? "fell" : "crashed")));
        }
    }

    void gameKeepsBestAndColour()
    {
        QTemporaryDir dir;
        const QString file = dir.filePath("settings.ini");
        {
            Game game(file);
            QCOMPARE(game.state(), Game::Ready);
            QCOMPARE(game.best(), 0);
            game.setBikeColor(3);
            game.setSeed(5);
            game.start();
            QCOMPARE(game.state(), Game::Running);
            // Ride straight on without doing anything: the track ends it.
            for (int i = 0; i < 60 * 60 && game.state() == Game::Running; ++i)
                game.step(1.0 / 60);
            QCOMPARE(game.state(), Game::Over);
            QVERIFY(game.score() > Tuning::SafeStart);
            QVERIFY(game.newBest());
            QCOMPARE(game.best(), game.score());
            QVERIFY(!game.deathReason().isEmpty());
        }
        Game again(file);
        QCOMPARE(again.bikeColor(), 3);
        QVERIFY(again.best() > Tuning::SafeStart);
    }

    void pauseStopsTheGame()
    {
        QTemporaryDir dir;
        Game game(dir.filePath("settings.ini"));
        game.setPaused(true);
        QVERIFY(!game.paused());   // nothing to pause yet
        game.start();
        game.setPaused(true);
        QVERIFY(game.paused());
        const double at = game.core().dist;
        game.step(0.5);
        game.right();
        QCOMPARE(game.core().dist, at);
        QCOMPARE(game.core().lane(), 1);
        game.setPaused(false);
        game.step(0.1);
        QVERIFY(game.core().dist > at);
        game.quit();
        QCOMPARE(game.state(), Game::Ready);
        QVERIFY(!game.paused());
    }

    void scoreSignals()
    {
        QTemporaryDir dir;
        Game game(dir.filePath("settings.ini"));
        game.start();
        QSignalSpy score(&game, &Game::scoreChanged);
        QSignalSpy frames(&game, &Game::frame);
        for (int i = 0; i < 60; ++i)
            game.step(1.0 / 60);
        QCOMPARE(game.score(), 9);   // 9 rows a second at the start
        QCOMPARE(score.count(), 9);
        QCOMPARE(frames.count(), 60);
    }
};

QTEST_MAIN(TestGame)
#include "tst_game.moc"

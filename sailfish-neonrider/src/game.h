#ifndef GAME_H
#define GAME_H

#include <QElapsedTimer>
#include <QObject>
#include <QString>
#include <QTimer>

#include "gamecore.h"

// The game as QML sees it: starts and stops the game loop, takes the
// button presses, and keeps the best distance and the bike's colour.
class Game : public QObject
{
    Q_OBJECT
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY pausedChanged)
    Q_PROPERTY(int score READ score NOTIFY scoreChanged)
    Q_PROPERTY(int best READ best NOTIFY bestChanged)
    Q_PROPERTY(bool newBest READ newBest NOTIFY stateChanged)
    Q_PROPERTY(QString deathReason READ deathReason NOTIFY stateChanged)
    Q_PROPERTY(int bikeColor READ bikeColor WRITE setBikeColor NOTIFY bikeColorChanged)
    Q_PROPERTY(int lane READ lane NOTIFY frame)

public:
    enum State { Ready, Running, Over };
    Q_ENUM(State)

    // settingsFile: where the best distance and colour are kept. Empty
    // means the app's own data directory.
    explicit Game(const QString &settingsFile = QString(), QObject *parent = nullptr);

    State state() const { return m_state; }
    bool paused() const { return m_paused; }
    void setPaused(bool paused);
    int score() const { return m_core.score(); }
    int best() const { return m_best; }
    bool newBest() const { return m_newBest; }
    QString deathReason() const;
    int bikeColor() const { return m_bikeColor; }
    int lane() const { return m_core.lane(); }
    void setBikeColor(int color);

    Q_INVOKABLE void start();
    Q_INVOKABLE void left();
    Q_INVOKABLE void right();
    Q_INVOKABLE void jump();
    // Back to the start screen, from pause or game over.
    Q_INVOKABLE void quit();

    // Moves the game on by dt seconds. The game loop calls it; tests call
    // it directly.
    void step(double dt);
    void setSeed(unsigned seed) { m_seed = seed; }
    const GameCore &core() const { return m_core; }
    GameCore &core() { return m_core; }

signals:
    void stateChanged();
    void pausedChanged();
    void scoreChanged();
    void bestChanged();
    void bikeColorChanged();
    // Something on screen moved: draw again.
    void frame();

private:
    void tick();
    void runLoop(bool run);
    void save();

    GameCore m_core;
    State m_state = Ready;
    bool m_paused = false;
    int m_best = 0;
    bool m_newBest = false;
    int m_bikeColor = 1;
    int m_lastScore = 0;
    unsigned m_seed = 0;
    QString m_settingsFile;
    QTimer m_timer;
    QElapsedTimer m_clock;
};

#endif

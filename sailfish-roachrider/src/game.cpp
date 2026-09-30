#include "game.h"

#include <QDir>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>
#include <random>

Game::Game(const QString &settingsFile, QObject *parent)
    : QObject(parent)
    , m_settingsFile(settingsFile)
{
    // Sailjail only lets the app write its own data directory,
    // ~/.local/share/org.veetalat/roachrider.
    if (m_settingsFile.isEmpty())
        m_settingsFile = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                + QStringLiteral("/settings.ini");
    QSettings settings(m_settingsFile, QSettings::IniFormat);
    m_best = qMax(0, settings.value(QStringLiteral("best"), 0).toInt());

    m_timer.setTimerType(Qt::PreciseTimer);
    m_timer.setInterval(16);
    connect(&m_timer, &QTimer::timeout, this, &Game::tick);

    // The start screen shows the tunnel too.
    m_core.reset(1);
}

QString Game::deathReason() const
{
    switch (m_core.status) {
    case GameCore::Fell: return QStringLiteral("The roach fell into the void");
    case GameCore::Crashed: return QStringLiteral("The roach hit a block");
    default: return QString();
    }
}

void Game::setPaused(bool paused)
{
    paused = paused && m_state == Running;
    if (paused == m_paused)
        return;
    m_paused = paused;
    runLoop(!paused && m_state == Running);
    emit pausedChanged();
}

void Game::start()
{
    m_core.reset(m_seed ? m_seed : std::random_device()());
    m_newBest = false;
    m_lastScore = 0;
    m_state = Running;
    m_paused = false;
    runLoop(true);
    emit stateChanged();
    emit pausedChanged();
    emit scoreChanged();
    emit frame();
}

void Game::quit()
{
    runLoop(false);
    m_core.reset(1);
    m_state = Ready;
    m_paused = false;
    m_lastScore = 0;
    emit stateChanged();
    emit pausedChanged();
    emit scoreChanged();
    emit frame();
}

qreal Game::speed() const
{
    return (GameCore::speedAt(m_core.dist) - Tuning::StartSpeed) / (Tuning::MaxSpeed - Tuning::StartSpeed);
}

void Game::left()
{
    if (m_state != Running || m_paused)
        return;
    const int before = m_core.target;
    m_core.left();
    if (m_core.target != before)
        emit moved();
}

void Game::right()
{
    if (m_state != Running || m_paused)
        return;
    const int before = m_core.target;
    m_core.right();
    if (m_core.target != before)
        emit moved();
}

void Game::jump()
{
    if (m_state != Running || m_paused)
        return;
    const bool before = m_core.airborne;
    m_core.jump();
    if (m_core.airborne && !before)
        emit jumped();
}

void Game::step(double dt)
{
    if (m_state != Running || m_paused)
        return;
    const double climbBefore = m_core.vh;
    m_core.step(dt);
    // A jump pressed just before landing starts here, landing and taking
    // off again in the same step. Gravity only ever slows the climb, so a
    // faster climb means a new jump.
    if (m_core.airborne && m_core.vh > climbBefore)
        emit jumped();
    if (m_core.score() != m_lastScore) {
        m_lastScore = m_core.score();
        emit scoreChanged();
    }
    if (m_core.status != GameCore::Running) {
        runLoop(false);
        m_state = Over;
        if (m_core.score() > m_best) {
            m_best = m_core.score();
            m_newBest = true;
            save();
            emit bestChanged();
        }
        emit stateChanged();
        if (m_core.status == GameCore::Crashed)
            emit crashed();
        else
            emit fell();
    }
    emit frame();
}

void Game::tick()
{
    // Real time since the last frame, but never a big jump after a stall.
    double dt = m_clock.nsecsElapsed() / 1e9;
    m_clock.restart();
    step(qMin(dt, 0.05));
}

void Game::runLoop(bool run)
{
    if (run) {
        m_clock.restart();
        m_timer.start();
    } else {
        m_timer.stop();
    }
}

void Game::save()
{
    QDir().mkpath(QFileInfo(m_settingsFile).absolutePath());
    QSettings settings(m_settingsFile, QSettings::IniFormat);
    settings.setValue(QStringLiteral("best"), m_best);
}

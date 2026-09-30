#include "gamecore.h"

#include <algorithm>
#include <cmath>

using namespace Tuning;

void GameCore::reset(unsigned seed)
{
    *this = GameCore();
    rng.seed(seed);
    ensureRows(Ahead);
}

void GameCore::setTrack(const std::vector<std::string> &track)
{
    reset(1);
    rows.clear();
    rowBase = 0;
    fixedTrack = true;
    for (const std::string &line : track) {
        Row r;
        for (int l = 0; l < Lanes; ++l) {
            char c = l < int(line.size()) ? line[l] : '.';
            r[l] = c == ' ' ? Hole : c == '#' ? Block : Tile;
        }
        rows.push_back(r);
    }
    ensureRows(Ahead);
}

int GameCore::wrap(int lane)
{
    return ((lane % Lanes) + Lanes) % Lanes;
}

double GameCore::faceValue(double p)
{
    double k = std::floor(p / 3);
    double d = p - 3 * k;
    return k + std::min(0.5, std::max(0.0, d - 2.5)) + std::min(0.0, std::max(-0.5, d - 0.5));
}

double GameCore::speedAt(double d)
{
    return std::min(MaxSpeed, std::sqrt(StartSpeed * StartSpeed + 2 * Accel * std::max(0.0, d)));
}

GameCore::Cell GameCore::cell(int row, int l) const
{
    if (row < rowBase || row >= rowBase + int(rows.size()))
        return Tile;
    return Cell(rows[row - rowBase][wrap(l)]);
}

void GameCore::left()
{
    if (status == Running && !falling)
        --target;
}

void GameCore::right()
{
    if (status == Running && !falling)
        ++target;
}

void GameCore::jump()
{
    if (status != Running || falling)
        return;
    if (airborne) {
        jumpQueued = JumpBuffer;
        return;
    }
    airborne = true;
    vh = JumpSpeed;
}

void GameCore::step(double dt)
{
    if (status != Running)
        return;
    time += dt;
    dist += speedAt(dist) * dt;

    // Sideways: glide to the middle of the lane the bike is heading for.
    double goal = target + 0.5;
    double move = LaneSpeed * dt;
    pos = std::fabs(goal - pos) <= move ? goal : pos + (goal > pos ? move : -move);
    camFace += (faceValue(pos) - camFace) * (1 - std::exp(-12 * dt));

    // Up and down.
    if (jumpQueued > 0)
        jumpQueued -= dt;
    if (airborne || falling) {
        vh -= Gravity * dt;
        h += vh * dt;
    }
    const int row = int(std::floor(dist));
    const int here = wrap(int(std::floor(pos)));
    if (falling) {
        if (h < -FallDepth)
            status = Fell;
    } else if (airborne) {
        if (h <= 0) {
            if (cell(row, here) == Hole) {
                falling = true;
                airborne = false;
            } else {
                h = vh = 0;
                airborne = false;
                if (jumpQueued > 0) {
                    jumpQueued = 0;
                    jump();
                }
            }
        }
    } else if (cell(row, here) == Hole) {
        falling = true;
        vh = 0;
    }

    // A block sits in the middle of its square, 0.6 long and 0.5 high.
    if (!falling && h < BlockHeight) {
        for (int r = int(std::floor(dist - BikeHalfLength)); r <= int(std::floor(dist + BikeHalfLength)); ++r) {
            if (cell(r, here) == Block && dist + BikeHalfLength > r + 0.2 && dist - BikeHalfLength < r + 0.8) {
                status = Crashed;
                break;
            }
        }
    }

    ensureRows(row + Ahead);
    while (rowBase < row - Behind && !rows.empty()) {
        rows.pop_front();
        ++rowBase;
    }
}

double GameCore::rnd()
{
    return std::uniform_real_distribution<double>(0, 1)(rng);
}

int GameCore::randInt(int lo, int hi)
{
    return std::uniform_int_distribution<int>(lo, hi)(rng);
}

void GameCore::ensureRows(int upTo)
{
    while (rowBase + int(rows.size()) <= upTo)
        generate();
}

// Adds one obstacle and the plain stretch after it. Every obstacle can be
// passed: by jumping, or by moving to a side that's still there. The plain
// stretch is longer than a jump, so there's time to land and get ready for
// the next one, and it grows as the bike speeds up.
void GameCore::generate()
{
    Row tiles;
    tiles.fill(Tile);
    const int at = rowBase + int(rows.size());
    if (fixedTrack || at < SafeStart) {
        rows.push_back(tiles);
        return;
    }
    const double d = std::min(1.0, (at - SafeStart) / 1500.0);   // difficulty, 0 to 1
    const double speed = speedAt(at);
    // Aim half the obstacles at the side the bike is on.
    const int face = rnd() < 0.5 ? lane() / 3 : randInt(0, 3);
    const double pick = rnd();

    if (pick < 0.36 || (pick >= 0.78 && d < 0.2)) {
        // One side of the tunnel is gone (later two, even three): ride on
        // another side.
        int faces = 1;
        if (d > 0.3 && rnd() < 0.45)
            faces = 2;
        if (d > 0.65 && rnd() < 0.25)
            faces = 3;
        const int dir = rnd() < 0.5 ? 1 : 3;
        Row r = tiles;
        for (int i = 0; i < faces; ++i) {
            int f = (face + i * dir) % 4;
            for (int s = 0; s < 3; ++s)
                r[f * 3 + s] = Hole;
        }
        for (int i = 0, n = randInt(5, 8 + int(6 * d)); i < n; ++i)
            rows.push_back(r);
    } else if (pick < 0.54) {
        // A gap all the way round: jump. Never longer than about half a jump.
        Row r;
        r.fill(Hole);
        const int longest = std::max(1, std::min(3, int(speed * airTime() * 0.55)));
        for (int i = 0, n = randInt(1, longest); i < n; ++i)
            rows.push_back(r);
    } else if (pick < 0.78) {
        // Blocks: jump over them or go round.
        Row r = tiles;
        if (rnd() < 0.5) {
            for (int l = 0; l < Lanes; ++l)
                if (rnd() < 0.3 + 0.3 * d)
                    r[l] = Block;
        } else {
            for (int s = 0; s < 3; ++s)
                r[face * 3 + s] = Block;
            if (d > 0.4)
                for (int l = 0; l < Lanes; ++l)
                    if (rnd() < 0.25)
                        r[l] = Block;
        }
        rows.push_back(r);
    } else {
        // Stripes: only the middle lanes are left, or only the outer ones.
        const bool middle = rnd() < 0.5;
        Row r = tiles;
        for (int l = 0; l < Lanes; ++l) {
            bool open = middle ? l % 3 == 1 : l % 3 != 1;
            if (!open)
                r[l] = Hole;
        }
        for (int i = 0, n = randInt(6, 10 + int(8 * d)); i < n; ++i)
            rows.push_back(r);
    }

    // Room to land from a late jump over the last obstacle, and then time
    // to get ready for the next.
    for (int i = 0, n = int(std::ceil(speed * airTime())) + 4; i < n; ++i)
        rows.push_back(tiles);
}

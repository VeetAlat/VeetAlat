#ifndef GAMECORE_H
#define GAMECORE_H

#include <array>
#include <deque>
#include <random>
#include <string>
#include <vector>

// The whole game without Qt: the track, the bike and the rules. It's plain
// data, so tests can copy it to try moves ahead of time.
//
// The tunnel is square with 3 lanes on each side, 12 lanes all round:
// lanes 0-2 are the floor (left to right), 3-5 the right wall (bottom to
// top), 6-8 the roof and 9-11 the left wall. Moving right from lane 2 goes
// up onto the right wall, and the view turns so the bike's side is always
// at the bottom. Distance along the tunnel is counted in rows; a row is as
// long as a lane is wide, so the grid is made of squares.
namespace Tuning {
const double HalfWidth = 1.5;       // the tunnel is 3 x 3, a lane is 1 wide
const double StartSpeed = 10.0;     // rows per second
const double MaxSpeed = 20.0;
const double Accel = 0.12;          // speed^2 grows by 2 * Accel every row
const double LaneSpeed = 12.0;      // lanes per second when changing lanes
const double Gravity = 30.4;
const double JumpSpeed = 7.6;       // jumps 0.95 high and lasts 0.5 s
const double BlockHeight = 0.5;
const double BikeHalfLength = 0.45;
const double FallDepth = 1.5;       // how far the bike falls before it's over
const double JumpBuffer = 0.12;     // a jump pressed this early still counts on landing
const int SafeStart = 20;           // rows of plain grid at the start
const int Ahead = 70;               // rows built ahead of the bike
const int Behind = 12;              // rows kept behind it
}

class GameCore
{
public:
    enum Cell { Tile = 0, Hole = 1, Block = 2 };
    enum Status { Running, Fell, Crashed };
    static const int Lanes = 12;

    void reset(unsigned seed);
    // Tests: a fixed track, one string of 12 per row: '.' tile, ' ' hole,
    // '#' block. Rows after the last one are plain grid.
    void setTrack(const std::vector<std::string> &rows);

    void step(double dt);
    void left();
    void right();
    void jump();

    Cell cell(int row, int lane) const;
    int lane() const { return wrap(target); }
    int score() const { return dist > 0 ? int(dist) : 0; }
    bool onGround() const { return !airborne && !falling; }

    static int wrap(int lane);
    // Which side of the tunnel a position is on, as a smooth number: 0 is
    // the floor, 1 the right wall and so on. It moves from one side to the
    // next over the half lanes either side of a corner, so the bike and
    // the view turn as the bike goes round.
    static double faceValue(double pos);
    static double speedAt(double dist);
    static double airTime() { return 2 * Tuning::JumpSpeed / Tuning::Gravity; }

    // Read by the renderer and the tests.
    Status status = Running;
    double dist = 0;        // how far along the tunnel the bike is, in rows
    double pos = 1.5;       // where round the tunnel it is, in lanes (not wrapped)
    int target = 1;         // the lane it's moving to (not wrapped)
    double h = 0;           // height above the surface
    double vh = 0;          // and how fast that changes
    bool airborne = false;
    bool falling = false;
    double camFace = 0;     // the view's turn, in sides (faceValue, smoothed)
    double time = 0;

private:
    typedef std::array<unsigned char, Lanes> Row;
    void ensureRows(int upTo);
    void generate();
    double rnd();
    int randInt(int lo, int hi);

    std::deque<Row> rows;
    int rowBase = 0;        // the row number of rows.front()
    std::mt19937 rng;
    bool fixedTrack = false;
    double jumpQueued = 0;
};

#endif

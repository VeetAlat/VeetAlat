#ifndef BOT_H
#define BOT_H

#include "../src/gamecore.h"

#include <cstdlib>

// A test player with perfect reactions. It tries moves on copies of the
// game and picks one that keeps the bike alive, together with a second
// move up to half a second later. If it can ride a long way, the track
// the game builds can be ridden.
namespace Bot {

struct Move {
    int lanes;   // negative: left
    bool jump;
};

inline void apply(GameCore &g, const Move &m)
{
    for (int i = 0; i < std::abs(m.lanes); ++i)
        m.lanes < 0 ? g.left() : g.right();
    if (m.jump)
        g.jump();
}

inline bool survives(GameCore g, double seconds)
{
    for (double t = 0; t < seconds && g.status == GameCore::Running; t += 1.0 / 60)
        g.step(1.0 / 60);
    return g.status == GameCore::Running;
}

inline const std::vector<Move> &moves()
{
    static std::vector<Move> list;
    if (list.empty()) {
        list.push_back({ 0, false });
        list.push_back({ 0, true });
        for (int k = 1; k <= 6; ++k) {
            list.push_back({ k, false });
            list.push_back({ -k, false });
            list.push_back({ k, true });
            list.push_back({ -k, true });
        }
    }
    return list;
}

inline Move decide(const GameCore &g)
{
    for (const Move &first : moves()) {
        GameCore later = g;
        apply(later, first);
        // The second move can come after any of these waits; the bot
        // decides again every tenth of a second, so it can always carry
        // out the plan.
        for (int wait = 1; wait <= 5 && later.status == GameCore::Running; ++wait) {
            for (int i = 0; i < 6 && later.status == GameCore::Running; ++i)
                later.step(1.0 / 60);
            for (const Move &second : moves()) {
                GameCore b = later;
                apply(b, second);
                if (survives(b, 0.9))
                    return first;
            }
        }
    }
    return { 0, false };
}

// Plays until `rows` or the end; returns how far it got.
inline int play(GameCore &g, int rows)
{
    // Decides ten times a second, every 6 frames: the same steps its plans
    // are made in.
    for (int frame = 0; g.status == GameCore::Running && g.dist < rows; ++frame) {
        if (frame % 6 == 0)
            apply(g, decide(g));
        g.step(1.0 / 60);
    }
    return g.score();
}

}

#endif

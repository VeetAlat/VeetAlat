#ifndef TUNNELVIEW_H
#define TUNNELVIEW_H

#include <QPointer>
#include <QQuickItem>

#include "game.h"

// Draws the game: the neon grid tunnel, the blocks and the bike, seen from
// behind the bike. Everything is built into one list of coloured triangles
// each frame and drawn in one go by the scene graph.
class TunnelView : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(Game *game READ game WRITE setGame NOTIFY gameChanged)

public:
    explicit TunnelView(QQuickItem *parent = nullptr);

    Game *game() const { return m_game; }
    void setGame(Game *game);

    // The bike colours, the same order as Game::bikeColor.
    static QColor bikeColor(int index);

signals:
    void gameChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;

private:
    QPointer<Game> m_game;
};

#endif

#ifndef TUNNELVIEW_H
#define TUNNELVIEW_H

#include <QImage>
#include <QPointer>
#include <QQuickItem>
#include <QUrl>

#include "game.h"

// Draws the game: the neon grid tunnel, the blocks and the roach on its
// bike, seen from behind. The tunnel and blocks are built into lists of
// coloured triangles each frame; the roach is a picture (bikeSource),
// rendered ahead of time from the 3D model.
class QSGTexture;

class TunnelView : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(Game *game READ game WRITE setGame NOTIFY gameChanged)
    Q_PROPERTY(QUrl bikeSource READ bikeSource WRITE setBikeSource NOTIFY bikeSourceChanged)
    Q_PROPERTY(bool showBike READ showBike WRITE setShowBike NOTIFY showBikeChanged)

public:
    explicit TunnelView(QQuickItem *parent = nullptr);

    Game *game() const { return m_game; }
    void setGame(Game *game);

    QUrl bikeSource() const { return m_bikeSource; }
    void setBikeSource(const QUrl &source);
    bool showBike() const { return m_showBike; }
    void setShowBike(bool show);

signals:
    void gameChanged();
    void bikeSourceChanged();
    void showBikeChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;

private:
    QPointer<Game> m_game;
    QUrl m_bikeSource;
    QImage m_bikeImage;
    bool m_bikeImageChanged = false;
    bool m_showBike = true;
    QSGTexture *m_bikeTexture = nullptr;   // used on the render thread
};

#endif

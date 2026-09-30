#include "tunnelview.h"

#include <QSGGeometryNode>
#include <QSGTexture>
#include <QSGTextureMaterial>
#include <QSGVertexColorMaterial>
#include <QQuickWindow>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>

namespace {

const double H = Tuning::HalfWidth;
const double NearZ = 0.25;
const double FogStart = 12;     // rows ahead of the camera where the grid starts to fade
const double FogEnd = 46;       // and where it's gone
const double CamBack = 4.5;     // the camera is this far behind the bike
const double CamHeight = 1.6;   // and this high above the bike's side
const double LineWidth = 0.009; // half the width of a grid line, in lane widths

struct V3 {
    double x, y, z;
};

V3 operator+(const V3 &a, const V3 &b) { return { a.x + b.x, a.y + b.y, a.z + b.z }; }
V3 operator-(const V3 &a, const V3 &b) { return { a.x - b.x, a.y - b.y, a.z - b.z }; }
V3 operator*(const V3 &a, double k) { return { a.x * k, a.y * k, a.z * k }; }
double dot(const V3 &a, const V3 &b) { return a.x * b.x + a.y * b.y + a.z * b.z; }

struct Rgba {
    float r, g, b, a;
    Rgba alpha(float k) const { return { r, g, b, a * k }; }
    Rgba mix(const Rgba &o, float t) const
    {
        return { r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t };
    }
};

Rgba hex(unsigned rgb, float a = 1)
{
    return { ((rgb >> 16) & 255) / 255.f, ((rgb >> 8) & 255) / 255.f, (rgb & 255) / 255.f, a };
}

const Rgba White = hex(0xffffff);
const Rgba Black = hex(0x000000);
const Rgba Grid = hex(0x19c6ff);        // the grid, electric blue
const Rgba Edge = hex(0xff2bd6);        // the tunnel's corners, magenta
const Rgba TileFill = hex(0x0c1a4d);
const Rgba HoleFill = hex(0x000000);
const Rgba HoleRim = hex(0xff5a1f);     // the edge of a hole, hot orange
const Rgba BlockFill = hex(0x2a0733, 0.95f);
const Rgba BlockEdge = hex(0xff3fd8);
const Rgba Glow = hex(0x9b2cff);        // the light at the end of the tunnel
const Rgba Trail = hex(0x19c6ff);
// The roach picture is square, this many lanes wide at the bike, with the
// model's lowest point this far (as a share of its size) above its bottom
// edge: tools/roach-render leaves room for the glow.
const double BikeSprite = 1.9;
const double BikeSpriteMargin = 0.14;

// A point on one side of the tunnel: u across it (-H at its left edge,
// seen standing on it), `lift` above it, at row position z.
V3 onSide(int face, double u, double lift, double z)
{
    const double x = u, y = -H + lift;
    switch (((face % 4) + 4) % 4) {
    case 0: return { x, y, z };
    case 1: return { -y, x, z };
    case 2: return { -x, -y, z };
    default: return { y, -x, z };
    }
}

V3 surface(double p, double z, double lift = 0)
{
    const int face = int(std::floor(p / 3));
    return onSide(face, -H + (p - 3 * face), lift, z);
}

class Painter
{
public:
    Painter(double width, double height, const GameCore &core)
    {
        const double a = -core.camFace * M_PI / 2;
        m_cos = std::cos(a);
        m_sin = std::sin(a);
        // The camera rises with a jump, most of the way, so the bike stays
        // clear of the far end of the tunnel and the ground drops away.
        m_camY = -H + CamHeight + 0.8 * std::max(0.0, core.h);
        m_camZ = core.dist - CamBack;
        m_f = width * 0.95;
        m_cx = width / 2;
        m_cy = height * 0.40;
        m_scale = width / 1080.0;
    }

    std::vector<QSGGeometry::ColoredPoint2D> v;

    // World to camera: turn the tunnel so the bike's side is at the bottom.
    V3 cam(const V3 &p) const
    {
        const double x = p.x * m_cos - p.y * m_sin;
        const double y = p.x * m_sin + p.y * m_cos;
        return { x, y - m_camY, p.z - m_camZ };
    }
    QPointF project(const V3 &c) const { return QPointF(m_cx + m_f * c.x / c.z, m_cy - m_f * c.y / c.z); }
    double camZ() const { return m_camZ; }

    static float fog(double z)
    {
        if (z <= FogStart)
            return 1;
        return float(std::max(0.0, 1 - (z - FogStart) / (FogEnd - FogStart)));
    }

    void vert(const QPointF &p, const Rgba &c)
    {
        const float a = std::max(0.f, std::min(1.f, c.a));
        QSGGeometry::ColoredPoint2D pt;
        pt.set(float(p.x()), float(p.y()),
               uchar(std::min(1.f, c.r) * a * 255), uchar(std::min(1.f, c.g) * a * 255),
               uchar(std::min(1.f, c.b) * a * 255), uchar(a * 255));
        v.push_back(pt);
    }

    void tri(const QPointF &p0, const Rgba &c0, const QPointF &p1, const Rgba &c1,
             const QPointF &p2, const Rgba &c2)
    {
        vert(p0, c0);
        vert(p1, c1);
        vert(p2, c2);
    }

    // A filled convex polygon, in camera space: cut off at the near plane,
    // faded with distance.
    void polygon(const std::vector<V3> &in, const Rgba &color)
    {
        std::vector<V3> pts;
        for (size_t i = 0; i < in.size(); ++i) {
            const V3 &a = in[i], &b = in[(i + 1) % in.size()];
            if (a.z >= NearZ)
                pts.push_back(a);
            if ((a.z >= NearZ) != (b.z >= NearZ))
                pts.push_back(a + (b - a) * ((NearZ - a.z) / (b.z - a.z)));
        }
        if (pts.size() < 3)
            return;
        const QPointF p0 = project(pts[0]);
        const Rgba c0 = color.alpha(fog(pts[0].z));
        for (size_t i = 1; i + 1 < pts.size(); ++i)
            tri(p0, c0, project(pts[i]), color.alpha(fog(pts[i].z)),
                project(pts[i + 1]), color.alpha(fog(pts[i + 1].z)));
    }

    // A neon line, in camera space: a wide soft glow, the line, and a
    // hot, whiter middle. `width` scales the line's thickness.
    void neon(V3 a, V3 b, const Rgba &color, double width = 1, float glow = 1)
    {
        if (a.z < NearZ && b.z < NearZ)
            return;
        if (a.z < NearZ)
            a = a + (b - a) * ((NearZ - a.z) / (b.z - a.z));
        else if (b.z < NearZ)
            b = b + (a - b) * ((NearZ - b.z) / (a.z - b.z));
        const QPointF pa = project(a), pb = project(b);
        const double wa = std::min(6.0 * m_scale, std::max(0.9, LineWidth * width * m_f / a.z));
        const double wb = std::min(6.0 * m_scale, std::max(0.9, LineWidth * width * m_f / b.z));
        const Rgba ca = color.alpha(fog(a.z)), cb = color.alpha(fog(b.z));
        // Far away, lines are too thin for the glow and the hot middle to
        // show: just the line, a third of the triangles.
        if (std::max(wa, wb) < 1.5) {
            strip(pa, pb, wa * 1.6, wb * 1.6, ca, cb);
            return;
        }
        if (glow > 0)
            strip(pa, pb, wa * 5, wb * 5, ca.alpha(0.32f * glow), cb.alpha(0.32f * glow));
        strip(pa, pb, wa * 1.6, wb * 1.6, ca, cb);
        strip(pa, pb, wa * 0.6, wb * 0.6, ca.mix(White, 0.6f), cb.mix(White, 0.6f));
    }

    // A line that fades out to both sides, so its edges are smooth.
    void strip(const QPointF &a, const QPointF &b, double wa, double wb, const Rgba &ca, const Rgba &cb)
    {
        const QPointF d = b - a;
        const double len = std::hypot(d.x(), d.y());
        if (len < 0.01)
            return;
        const QPointF n(-d.y() / len, d.x() / len);
        const Rgba clear = { 0, 0, 0, 0 };
        for (int side = -1; side <= 1; side += 2) {
            const QPointF ea = a + n * (wa * side), eb = b + n * (wb * side);
            tri(a, ca, b, cb, eb, clear);
            tri(a, ca, eb, clear, ea, clear);
        }
    }

    // A soft round glow, bright in the middle.
    void glowDisc(const QPointF &c, double r, const Rgba &color)
    {
        const int n = 40;
        const Rgba clear = color.alpha(0);
        for (int i = 0; i < n; ++i) {
            const double a0 = 2 * M_PI * i / n, a1 = 2 * M_PI * (i + 1) / n;
            tri(c, color, c + QPointF(r * std::cos(a0), r * std::sin(a0)), clear,
                c + QPointF(r * std::cos(a1), r * std::sin(a1)), clear);
        }
    }

    // A solid, convex eight-cornered shape (a box or a wedge), in world
    // space. Corner i has bit 0 for its lateral side, bit 1 for top and
    // bit 2 for front. Only the faces turned to the camera are drawn.
    void solid(const V3 world[8], const Rgba &fill, const Rgba &edge, double edgeWidth = 1)
    {
        static const int faces[6][4] = {
            { 0, 2, 6, 4 }, { 1, 5, 7, 3 }, { 0, 4, 5, 1 }, { 2, 3, 7, 6 }, { 0, 1, 3, 2 }, { 4, 6, 7, 5 }
        };
        V3 c[8];
        V3 mid = { 0, 0, 0 };
        for (int i = 0; i < 8; ++i) {
            c[i] = cam(world[i]);
            mid = mid + c[i] * 0.125;
        }
        bool edges[8][8] = {};
        for (const auto &f : faces) {
            const V3 fc = (c[f[0]] + c[f[1]] + c[f[2]] + c[f[3]]) * 0.25;
            if (dot(fc - mid, fc) >= 0)
                continue;   // turned away
            polygon({ c[f[0]], c[f[1]], c[f[2]], c[f[3]] }, fill);
            for (int k = 0; k < 4; ++k) {
                const int a = std::min(f[k], f[(k + 1) % 4]), b = std::max(f[k], f[(k + 1) % 4]);
                edges[a][b] = true;
            }
        }
        for (int a = 0; a < 8; ++a)
            for (int b = a + 1; b < 8; ++b)
                if (edges[a][b])
                    neon(c[a], c[b], edge, edgeWidth, 0.6f);
    }

private:
    double m_cos, m_sin, m_camY, m_camZ, m_f, m_cx, m_cy, m_scale;
};

void drawTunnel(Painter &p, const GameCore &g)
{
    const int first = int(std::floor(p.camZ() + NearZ)) - 1;
    const int last = int(std::ceil(p.camZ() + FogEnd));
    const int lanes = GameCore::Lanes;

    // Every square: dark blue, or black where there's a hole.
    for (int r = last; r >= first; --r) {
        for (int l = 0; l < lanes; ++l) {
            p.polygon({ p.cam(surface(l, r)), p.cam(surface(l + 1, r)),
                        p.cam(surface(l + 1, r + 1)), p.cam(surface(l, r + 1)) },
                      g.cell(r, l) == GameCore::Hole ? HoleFill : TileFill);
        }
    }

    // Grid lines along the tunnel, magenta in the corners and orange round
    // the holes.
    for (int r = last; r >= first; --r) {
        for (int b = 0; b < lanes; ++b) {
            const bool holeLeft = g.cell(r, b - 1) == GameCore::Hole, holeRight = g.cell(r, b) == GameCore::Hole;
            if (holeLeft && holeRight)
                continue;
            const bool corner = b % 3 == 0;
            p.neon(p.cam(surface(b, r)), p.cam(surface(b, r + 1)),
                   holeLeft != holeRight ? HoleRim : corner ? Edge : Grid, corner ? 1.6 : 1);
        }
    }
    // And across it, at the start of every row.
    for (int r = last; r >= first; --r) {
        for (int l = 0; l < lanes; ++l) {
            const bool holeBefore = g.cell(r - 1, l) == GameCore::Hole, holeAfter = g.cell(r, l) == GameCore::Hole;
            if (holeBefore && holeAfter)
                continue;
            p.neon(p.cam(surface(l, r)), p.cam(surface(l + 1, r)), holeBefore != holeAfter ? HoleRim : Grid);
        }
    }
}

void drawBlock(Painter &p, int row, int lane)
{
    const int face = lane / 3;
    const double u0 = -H + lane % 3 + 0.15;
    V3 c[8];
    for (int i = 0; i < 8; ++i)
        c[i] = onSide(face, u0 + (i & 1 ? 0.7 : 0), i & 2 ? Tuning::BlockHeight : 0, row + (i & 4 ? 0.8 : 0.2));
    p.solid(c, BlockFill, BlockEdge, 1.4);
}

// Under the bike: its shadow while it's in the air, and a light trail.
void drawBikeGround(Painter &p, const GameCore &g)
{
    const double roll = GameCore::faceValue(g.pos) * M_PI / 2;
    const V3 base = surface(g.pos, g.dist);
    const V3 side = { std::cos(roll), std::sin(roll), 0 };
    const V3 up = { -std::sin(roll), std::cos(roll), 0 };

    // In the air, a shadow on the ground shows where the bike will land.
    if (g.airborne) {
        std::vector<V3> shadow;
        for (int i = 0; i < 16; ++i) {
            const double a = 2 * M_PI * i / 16;
            shadow.push_back(p.cam(base + side * (0.25 * std::cos(a)) + up * 0.01 + V3{ 0, 0, 0.7 * std::sin(a) }));
        }
        p.polygon(shadow, Black.alpha(float(0.6 - 0.3 * g.h)));
    }

    // A light trail on the ground behind the bike.
    if (!g.falling) {
        const double lift = 0.02;
        const V3 t0 = p.cam(base + side * -0.07 + up * lift + V3{ 0, 0, -0.35 });
        const V3 t1 = p.cam(base + side * 0.07 + up * lift + V3{ 0, 0, -0.35 });
        const V3 t2 = p.cam(base + side * 0.07 + up * lift + V3{ 0, 0, -2.4 });
        const V3 t3 = p.cam(base + side * -0.07 + up * lift + V3{ 0, 0, -2.4 });
        if (t2.z > NearZ && t3.z > NearZ) {
            const Rgba on = Trail.alpha(0.5f), off = Trail.alpha(0);
            p.tri(p.project(t0), on, p.project(t1), on, p.project(t2), off);
            p.tri(p.project(t0), on, p.project(t2), off, p.project(t3), off);
        }
    }
}

// Where the roach picture goes on screen: its four corners, top left, bottom
// left, top right, bottom right. The picture (qml/images/roach-back.png) is
// the model seen from behind, as the game's camera sees it; it stands on the
// bike's spot and leans with the bike round corners. False if it's behind
// the camera.
bool bikeCorners(const Painter &p, const GameCore &g, QPointF corners[4])
{
    const double roll = GameCore::faceValue(g.pos) * M_PI / 2;
    const V3 up = { -std::sin(roll), std::cos(roll), 0 };
    const V3 foot = surface(g.pos, g.dist) + up * g.h;
    const V3 c0 = p.cam(foot), c1 = p.cam(foot + up);
    if (c0.z < NearZ || c1.z < NearZ)
        return false;
    const QPointF s0 = p.project(c0), s1 = p.project(c1);
    const QPointF upv = s1 - s0;
    const double k = std::hypot(upv.x(), upv.y());     // pixels per unit, going up
    if (k < 1e-6)
        return false;
    const QPointF u = upv / k, right(-u.y(), u.x());
    const double size = BikeSprite * k;
    const QPointF bottom = s0 - u * (BikeSpriteMargin * size);
    const QPointF half = right * (size / 2), tall = u * size;
    corners[0] = bottom - half + tall;
    corners[1] = bottom - half;
    corners[2] = bottom + half + tall;
    corners[3] = bottom + half;
    return true;
}

} // namespace

TunnelView::TunnelView(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);
}

void TunnelView::setGame(Game *game)
{
    if (game == m_game)
        return;
    if (m_game)
        disconnect(m_game, nullptr, this, nullptr);
    m_game = game;
    if (m_game)
        connect(m_game, &Game::frame, this, &QQuickItem::update);
    update();
    emit gameChanged();
}

void TunnelView::setBikeSource(const QUrl &source)
{
    if (source == m_bikeSource)
        return;
    m_bikeSource = source;
    const QString file = source.isLocalFile() ? source.toLocalFile() : source.toString();
    m_bikeImage = QImage(file).convertToFormat(QImage::Format_ARGB32_Premultiplied);
    if (m_bikeImage.isNull())
        qWarning("TunnelView: can't load the bike picture %s", qPrintable(file));
    m_bikeImageChanged = true;
    update();
    emit bikeSourceChanged();
}

void TunnelView::setShowBike(bool show)
{
    if (show == m_showBike)
        return;
    m_showBike = show;
    update();
    emit showBikeChanged();
}

namespace {

QSGGeometryNode *colouredNode()
{
    QSGGeometryNode *node = new QSGGeometryNode;
    QSGGeometry *geometry = new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(), 0);
    geometry->setDrawingMode(GL_TRIANGLES);
    geometry->setVertexDataPattern(QSGGeometry::StreamPattern);
    node->setGeometry(geometry);
    node->setFlag(QSGNode::OwnsGeometry);
    node->setMaterial(new QSGVertexColorMaterial);
    node->setFlag(QSGNode::OwnsMaterial);
    return node;
}

void fill(QSGGeometryNode *node, const std::vector<QSGGeometry::ColoredPoint2D> &vertices)
{
    QSGGeometry *geometry = node->geometry();
    geometry->allocate(int(vertices.size()));
    if (!vertices.empty())
        std::memcpy(geometry->vertexDataAsColoredPoint2D(), vertices.data(),
                    vertices.size() * sizeof(QSGGeometry::ColoredPoint2D));
    node->markDirty(QSGNode::DirtyGeometry);
}

}

// Three layers: the tunnel and everything farther away than the bike, the
// roach, then the few blocks between the bike and the camera.
QSGNode *TunnelView::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    QSGNode *root = oldNode;
    if (!root) {
        root = new QSGNode;
        root->appendChildNode(colouredNode());
        QSGGeometryNode *bike = new QSGGeometryNode;
        QSGGeometry *geometry = new QSGGeometry(QSGGeometry::defaultAttributes_TexturedPoint2D(), 4);
        geometry->setDrawingMode(GL_TRIANGLE_STRIP);
        bike->setGeometry(geometry);
        bike->setFlag(QSGNode::OwnsGeometry);
        QSGTextureMaterial *material = new QSGTextureMaterial;
        material->setFiltering(QSGTexture::Linear);
        material->setMipmapFiltering(QSGTexture::None);
        material->setFlag(QSGMaterial::Blending, true);
        bike->setMaterial(material);
        bike->setFlag(QSGNode::OwnsMaterial);
        root->appendChildNode(bike);
        root->appendChildNode(colouredNode());
    }
    QSGGeometryNode *farNode = static_cast<QSGGeometryNode *>(root->childAtIndex(0));
    QSGGeometryNode *bikeNode = static_cast<QSGGeometryNode *>(root->childAtIndex(1));
    QSGGeometryNode *nearNode = static_cast<QSGGeometryNode *>(root->childAtIndex(2));

    // The roach picture goes to the graphics card once.
    if (m_bikeImageChanged && window()) {
        m_bikeImageChanged = false;
        delete m_bikeTexture;
        m_bikeTexture = m_bikeImage.isNull() ? nullptr : window()->createTextureFromImage(m_bikeImage);
        static_cast<QSGTextureMaterial *>(bikeNode->material())->setTexture(m_bikeTexture);
        bikeNode->markDirty(QSGNode::DirtyMaterial);
    }

    std::vector<QSGGeometry::ColoredPoint2D> farVertices, nearVertices;
    bool bikeShown = false;
    QPointF corners[4];
    if (m_game && width() > 0 && height() > 0) {
        const GameCore &g = m_game->core();
        Painter p(width(), height(), g);
        p.v.reserve(60000);

        // The light at the end of the tunnel.
        p.glowDisc(p.project({ 0, 0, 1 }), width() * 0.55, Glow.alpha(0.5f));
        drawTunnel(p, g);

        // Blocks farthest first, so nearer ones cover them.
        std::vector<std::pair<int, int>> blocks;
        const int first = int(std::floor(p.camZ() + NearZ)) - 1;
        const int last = int(std::ceil(p.camZ() + FogEnd));
        for (int r = last; r >= first; --r)
            for (int l = 0; l < GameCore::Lanes; ++l)
                if (g.cell(r, l) == GameCore::Block)
                    blocks.push_back({ r, l });
        size_t i = 0;
        for (; i < blocks.size() && blocks[i].first + 0.5 > g.dist; ++i)
            drawBlock(p, blocks[i].first, blocks[i].second);
        if (m_showBike) {
            drawBikeGround(p, g);
            bikeShown = m_bikeTexture && bikeCorners(p, g, corners);
        }
        farVertices.swap(p.v);
        for (; i < blocks.size(); ++i)
            drawBlock(p, blocks[i].first, blocks[i].second);
        nearVertices.swap(p.v);
    }

    fill(farNode, farVertices);
    fill(nearNode, nearVertices);
    QSGGeometry *geometry = bikeNode->geometry();
    QSGGeometry::TexturedPoint2D *v = geometry->vertexDataAsTexturedPoint2D();
    if (bikeShown) {
        v[0].set(float(corners[0].x()), float(corners[0].y()), 0, 0);
        v[1].set(float(corners[1].x()), float(corners[1].y()), 0, 1);
        v[2].set(float(corners[2].x()), float(corners[2].y()), 1, 0);
        v[3].set(float(corners[3].x()), float(corners[3].y()), 1, 1);
    } else {
        for (int k = 0; k < 4; ++k)
            v[k].set(0, 0, 0, 0);
    }
    bikeNode->markDirty(QSGNode::DirtyGeometry);
    return root;
}

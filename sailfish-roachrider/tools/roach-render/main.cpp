// Renders the roach model (tools/roach.obj, a Tinkercad export) to a PNG
// with a transparent background: flat shaded in the model's own colours,
// with a neon rim light and an optional neon outline, so it fits the game.
// The game uses these pictures instead of drawing 35 000 triangles a frame.
//
// Usage: roach-render <model.obj> <out.png> <size> <yaw> <pitch> [outline]
//   yaw:     degrees round the up axis; 0 looks at the roach's face
//   pitch:   degrees above the horizon the camera looks down from
//   outline: 1 for a soft neon glow round the outline

#include <QColor>
#include <QFile>
#include <QGuiApplication>
#include <QImage>
#include <QTextStream>
#include <QVector3D>
#include <QVector>
#include <algorithm>
#include <cmath>
#include <limits>

namespace {

struct Tri {
    int a, b, c;
    QColor color;
};

bool load(const QString &path, QVector<QVector3D> &verts, QVector<Tri> &tris)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return false;
    QTextStream in(&f);
    QColor color(Qt::gray);
    while (!in.atEnd()) {
        const QStringList p = in.readLine().simplified().split(' ');
        if (p.isEmpty())
            continue;
        if (p[0] == "v" && p.size() >= 4) {
            verts.append(QVector3D(p[1].toFloat(), p[2].toFloat(), p[3].toFloat()));
        } else if (p[0] == "usemtl" && p.size() >= 2 && p[1].startsWith("color_")) {
            // Tinkercad names each material after its colour, as a number.
            color = QColor(QRgb(p[1].mid(6).toUInt()));
        } else if (p[0] == "f" && p.size() >= 4) {
            QVector<int> idx;
            for (int i = 1; i < p.size(); ++i)
                idx.append(p[i].section('/', 0, 0).toInt() - 1);
            for (int i = 1; i + 1 < idx.size(); ++i)
                tris.append({ idx[0], idx[i], idx[i + 1], color });
        }
    }
    return true;
}

double edge(double ax, double ay, double bx, double by, double px, double py)
{
    return (bx - ax) * (py - ay) - (by - ay) * (px - ax);
}

} // namespace

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    if (argc < 6) {
        qWarning("usage: roach-render model.obj out.png size yaw pitch [outline]");
        return 2;
    }
    const int size = atoi(argv[3]);
    const double yaw = atof(argv[4]) * M_PI / 180, pitch = atof(argv[5]) * M_PI / 180;
    const bool outline = argc > 6 && atoi(argv[6]);

    QVector<QVector3D> verts;
    QVector<Tri> tris;
    if (!load(QString::fromLocal8Bit(argv[1]), verts, tris) || tris.isEmpty()) {
        qWarning("can't read the model");
        return 1;
    }

    // Model: z up, the roach faces -y. Centre it.
    QVector3D lo = verts[0], hi = verts[0];
    for (const QVector3D &v : verts) {
        lo = QVector3D(std::min(lo.x(), v.x()), std::min(lo.y(), v.y()), std::min(lo.z(), v.z()));
        hi = QVector3D(std::max(hi.x(), v.x()), std::max(hi.y(), v.y()), std::max(hi.z(), v.z()));
    }
    const QVector3D mid = (lo + hi) / 2;

    // Camera space: x right, y up, z towards the viewer.
    auto view = [&](const QVector3D &p) {
        QVector3D q = p - mid;
        // Turn round the up axis, then tip the camera down by `pitch`.
        const double x = q.x() * std::cos(yaw) - q.y() * std::sin(yaw);
        const double d = q.x() * std::sin(yaw) + q.y() * std::cos(yaw);   // depth, away from the viewer at yaw 0
        const double y = q.z();
        const double y2 = y * std::cos(pitch) + d * std::sin(pitch);
        const double d2 = -y * std::sin(pitch) + d * std::cos(pitch);
        return QVector3D(float(x), float(y2), float(-d2));
    };

    QVector<QVector3D> cam(verts.size());
    double r = 0;
    for (int i = 0; i < verts.size(); ++i) {
        cam[i] = view(verts[i]);
        r = std::max(r, double(std::hypot(cam[i].x(), cam[i].y())));
    }

    const int ss = 3;                         // supersampling
    const int n = size * ss;
    const double margin = outline ? 0.14 : 0.04;
    const double scale = n * (0.5 - margin) / r;
    // Fit the actual bounds to the picture, centred.
    double minx = 1e9, maxx = -1e9, miny = 1e9, maxy = -1e9;
    for (const QVector3D &c : cam) {
        minx = std::min(minx, double(c.x())); maxx = std::max(maxx, double(c.x()));
        miny = std::min(miny, double(c.y())); maxy = std::max(maxy, double(c.y()));
    }
    const double fit = std::min(n * (1 - 2 * margin) / (maxx - minx), n * (1 - 2 * margin) / (maxy - miny));
    Q_UNUSED(scale);
    const double ox = n / 2.0 - fit * (minx + maxx) / 2, oy = n / 2.0 + fit * (miny + maxy) / 2;

    std::vector<float> depth(size_t(n) * n, -std::numeric_limits<float>::infinity());
    QImage big(n, n, QImage::Format_ARGB32);
    big.fill(Qt::transparent);

    const QVector3D light = QVector3D(-0.4f, 0.7f, 0.6f).normalized();
    const QColor rimLeft(0xff, 0x2b, 0xd6), rimRight(0x19, 0xc6, 0xff);

    for (const Tri &t : tris) {
        const QVector3D &a = cam[t.a], &b = cam[t.b], &c = cam[t.c];
        QVector3D nrm = QVector3D::crossProduct(b - a, c - a);
        if (nrm.length() < 1e-9f)
            continue;
        nrm.normalize();
        if (nrm.z() < 0)
            nrm = -nrm;      // Tinkercad's winding isn't reliable: light both sides

        const double diffuse = std::max(0.0, double(QVector3D::dotProduct(nrm, light)));
        const double shade = 0.38 + 0.62 * diffuse;
        const double rim = std::pow(1 - std::fabs(double(nrm.z())), 3.0);
        const QColor &rc = nrm.x() < 0 ? rimLeft : rimRight;
        const double rr = std::min(255.0, t.color.red() * shade + rc.red() * rim * 0.9);
        const double rg = std::min(255.0, t.color.green() * shade + rc.green() * rim * 0.9);
        const double rb = std::min(255.0, t.color.blue() * shade + rc.blue() * rim * 0.9);
        const QRgb px = qRgba(int(rr), int(rg), int(rb), 255);

        const double ax = ox + a.x() * fit, ay = oy - a.y() * fit;
        const double bx = ox + b.x() * fit, by = oy - b.y() * fit;
        const double cx = ox + c.x() * fit, cy = oy - c.y() * fit;
        const double area = edge(ax, ay, bx, by, cx, cy);
        if (std::fabs(area) < 1e-9)
            continue;
        const int x0 = std::max(0, int(std::floor(std::min({ ax, bx, cx }))));
        const int x1 = std::min(n - 1, int(std::ceil(std::max({ ax, bx, cx }))));
        const int y0 = std::max(0, int(std::floor(std::min({ ay, by, cy }))));
        const int y1 = std::min(n - 1, int(std::ceil(std::max({ ay, by, cy }))));
        for (int y = y0; y <= y1; ++y) {
            QRgb *line = reinterpret_cast<QRgb *>(big.scanLine(y));
            for (int x = x0; x <= x1; ++x) {
                const double px_ = x + 0.5, py_ = y + 0.5;
                double w0 = edge(bx, by, cx, cy, px_, py_) / area;
                double w1 = edge(cx, cy, ax, ay, px_, py_) / area;
                double w2 = edge(ax, ay, bx, by, px_, py_) / area;
                if (w0 < 0 || w1 < 0 || w2 < 0)
                    continue;
                const float z = float(w0 * a.z() + w1 * b.z() + w2 * c.z());
                float &d = depth[size_t(y) * n + x];
                if (z > d) {
                    d = z;
                    line[x] = px;
                }
            }
        }
    }

    // Shrink to the final size, averaging the supersamples.
    QImage out = big.convertToFormat(QImage::Format_ARGB32_Premultiplied)
                     .scaled(size, size, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);

    if (outline) {
        // A soft glow round the outline, magenta above fading to cyan below.
        QImage glow(size, size, QImage::Format_ARGB32_Premultiplied);
        glow.fill(Qt::transparent);
        const int rad = std::max(2, size / 40);
        std::vector<float> a(size_t(size) * size), tmp(a.size());
        for (int y = 0; y < size; ++y)
            for (int x = 0; x < size; ++x)
                a[size_t(y) * size + x] = qAlpha(out.pixel(x, y)) / 255.f;
        // Box blur three times, across then down: close to a Gaussian.
        for (int pass = 0; pass < 3; ++pass) {
            for (int y = 0; y < size; ++y)
                for (int x = 0; x < size; ++x) {
                    float s = 0; int cnt = 0;
                    for (int k = -rad; k <= rad; ++k) { int xx = x + k; if (xx >= 0 && xx < size) { s += a[size_t(y) * size + xx]; ++cnt; } }
                    tmp[size_t(y) * size + x] = s / cnt;
                }
            for (int y = 0; y < size; ++y)
                for (int x = 0; x < size; ++x) {
                    float s = 0; int cnt = 0;
                    for (int k = -rad; k <= rad; ++k) { int yy = y + k; if (yy >= 0 && yy < size) { s += tmp[size_t(yy) * size + x]; ++cnt; } }
                    a[size_t(y) * size + x] = s / cnt;
                }
        }
        for (int y = 0; y < size; ++y) {
            const double t = double(y) / size;
            const QColor c = QColor::fromRgbF(1 - 0.9 * t, 0.17 + 0.6 * t, 0.84 + 0.16 * t);
            for (int x = 0; x < size; ++x) {
                const float al = std::min(1.f, a[size_t(y) * size + x] * 2.2f) * 0.85f;
                glow.setPixel(x, y, qPremultiply(qRgba(c.red(), c.green(), c.blue(), int(al * 255))));
            }
        }
        QImage combined = glow;
        for (int y = 0; y < size; ++y)
            for (int x = 0; x < size; ++x) {
                const QRgb s = out.pixel(x, y);
                const QRgb g = combined.pixel(x, y);
                const double sa = qAlpha(s) / 255.0;
                combined.setPixel(x, y, qRgba(int(qRed(s) + qRed(g) * (1 - sa)), int(qGreen(s) + qGreen(g) * (1 - sa)),
                                              int(qBlue(s) + qBlue(g) * (1 - sa)), int(qAlpha(s) + qAlpha(g) * (1 - sa))));
            }
        out = combined;
    }

    if (!out.convertToFormat(QImage::Format_ARGB32).save(QString::fromLocal8Bit(argv[2]))) {
        qWarning("can't save");
        return 1;
    }
    return 0;
}

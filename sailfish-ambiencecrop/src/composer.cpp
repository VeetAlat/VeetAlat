#include "composer.h"

#include <QColor>
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusError>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDir>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QImageReader>
#include <QPainter>
#include <QStandardPaths>
#include <QTimer>
#include <QTransform>
#include <QUrl>
#include <QtConcurrent>

namespace {

QString localPath(const QString &source)
{
    if (source.startsWith(QLatin1String("file:")))
        return QUrl(source).toLocalFile();
    return source;
}

int squareSize(const QVariantMap &layout)
{
    return qBound(256, layout.value(QStringLiteral("size"), 2048).toInt(), 4096);
}

// The photo scaled to cover a size x size square, centred.
QImage cover(const QImage &photo, int size)
{
    QImage scaled = photo.scaled(size, size, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
    return scaled.copy((scaled.width() - size) / 2, (scaled.height() - size) / 2, size, size)
                 .convertToFormat(QImage::Format_RGB32);
}

QColor averageColour(const QImage &photo)
{
    QImage one = photo.scaled(16, 16, Qt::IgnoreAspectRatio, Qt::SmoothTransformation).convertToFormat(QImage::Format_RGB32);
    qint64 r = 0, g = 0, b = 0;
    for (int y = 0; y < one.height(); y++) {
        const QRgb *line = reinterpret_cast<const QRgb *>(one.constScanLine(y));
        for (int x = 0; x < one.width(); x++) {
            r += qRed(line[x]); g += qGreen(line[x]); b += qBlue(line[x]);
        }
    }
    const int n = one.width() * one.height();
    return QColor(int(r / n), int(g / n), int(b / n));
}

} // namespace

Composer::Composer(QObject *parent)
    : QObject(parent),
      m_outputDir(QStandardPaths::writableLocation(QStandardPaths::PicturesLocation) + QStringLiteral("/AmbienceCrop"))
{
}

void Composer::setOutputDir(const QString &dir)
{
    if (dir == m_outputDir)
        return;
    m_outputDir = dir;
    emit outputDirChanged();
}

QImage Composer::load(const QString &source, int rotation, QString *error)
{
    QImageReader reader(localPath(source));
    reader.setAutoTransform(true); // the camera's EXIF orientation
    // Very big photos are read smaller: more than enough for a 4096 square.
    const QSize size = reader.size();
    if (size.isValid() && qMax(size.width(), size.height()) > 8192)
        reader.setScaledSize(size.scaled(8192, 8192, Qt::KeepAspectRatio));
    QImage image = reader.read();
    if (image.isNull()) {
        if (error)
            *error = reader.errorString();
        return image;
    }
    rotation = ((rotation % 360) + 360) % 360;
    if (rotation != 0)
        image = image.transformed(QTransform().rotate(rotation), Qt::SmoothTransformation);
    return image.convertToFormat(QImage::Format_ARGB32_Premultiplied);
}

QVariantMap Composer::inspect(const QString &source) const
{
    QVariantMap out;
    QImageReader reader(localPath(source));
    reader.setAutoTransform(true);
    QSize size = reader.size();
    if (!size.isValid() || !reader.canRead()) {
        out.insert(QStringLiteral("ok"), false);
        out.insert(QStringLiteral("error"), reader.errorString());
        return out;
    }
    // The EXIF orientation turns some photos a quarter turn.
    const QImageIOHandler::Transformations t = reader.transformation();
    if (t & QImageIOHandler::TransformationRotate90)
        size.transpose();
    out.insert(QStringLiteral("ok"), true);
    out.insert(QStringLiteral("width"), size.width());
    out.insert(QStringLiteral("height"), size.height());
    return out;
}

// A three-pass box blur (close to a Gaussian), in place, on RGB32.
void Composer::boxBlur(QImage &image, int radius)
{
    if (radius < 1)
        return;
    image = image.convertToFormat(QImage::Format_RGB32);
    const int w = image.width(), h = image.height();
    QVector<QRgb> line(qMax(w, h));
    for (int pass = 0; pass < 3; pass++) {
        for (int dir = 0; dir < 2; dir++) {
            const int len = dir == 0 ? w : h, lines = dir == 0 ? h : w;
            for (int l = 0; l < lines; l++) {
                // Copy one row or column out, blur it back in.
                for (int i = 0; i < len; i++)
                    line[i] = dir == 0 ? reinterpret_cast<const QRgb *>(image.constScanLine(l))[i]
                                       : reinterpret_cast<const QRgb *>(image.constScanLine(i))[l];
                int r = 0, g = 0, b = 0;
                const int n = 2 * radius + 1;
                for (int k = -radius; k <= radius; k++) {
                    const QRgb p = line[qBound(0, k, len - 1)];
                    r += qRed(p); g += qGreen(p); b += qBlue(p);
                }
                for (int i = 0; i < len; i++) {
                    const QRgb v = qRgb(r / n, g / n, b / n);
                    if (dir == 0)
                        reinterpret_cast<QRgb *>(image.scanLine(l))[i] = v;
                    else
                        reinterpret_cast<QRgb *>(image.scanLine(i))[l] = v;
                    const QRgb out = line[qBound(0, i - radius, len - 1)];
                    const QRgb in = line[qBound(0, i + radius + 1, len - 1)];
                    r += qRed(in) - qRed(out); g += qGreen(in) - qGreen(out); b += qBlue(in) - qBlue(out);
                }
            }
        }
    }
}

QImage Composer::background(const QImage &photo, int size, const QVariantMap &layout)
{
    const QString mode = layout.value(QStringLiteral("background"), QStringLiteral("blur")).toString();
    const qreal dim = qBound<qreal>(0.0, layout.value(QStringLiteral("dim"), 0.3).toReal(), 1.0);
    QImage bg;
    if (mode == QLatin1String("black")) {
        bg = QImage(size, size, QImage::Format_RGB32);
        bg.fill(Qt::black);
    } else if (mode == QLatin1String("colour")) {
        bg = QImage(size, size, QImage::Format_RGB32);
        bg.fill(averageColour(photo));
    } else {
        const qreal blur = qBound<qreal>(0.0, layout.value(QStringLiteral("blur"), 0.5).toReal(), 1.0);
        // The blur's radius is a share of the side, so the preview and
        // the saved image look the same. Blurring a smaller copy is fast,
        // and scaling it back up smooths it further.
        const qreal radius = blur * size * 0.05;
        const int factor = qMax(1, int(radius / 6));
        bg = cover(photo, qMax(8, size / factor));
        boxBlur(bg, qMax(blur > 0 ? 1 : 0, int(radius / factor + 0.5)));
        if (factor > 1)
            bg = bg.scaled(size, size, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    }
    if (dim > 0 && mode != QLatin1String("black")) {
        QPainter p(&bg);
        p.fillRect(bg.rect(), QColor(0, 0, 0, int(dim * 255 + 0.5)));
    }
    return bg.convertToFormat(QImage::Format_RGB32);
}

QImage Composer::compose(const QImage &photo, const QVariantMap &layout)
{
    const int size = squareSize(layout);
    QImage out = background(photo, size, layout);
    const qreal cx = layout.value(QStringLiteral("cx"), 0.5).toReal();
    const qreal cy = layout.value(QStringLiteral("cy"), 0.5).toReal();
    const qreal scale = qBound<qreal>(0.01, layout.value(QStringLiteral("scale"), 1.0).toReal(), 20.0);
    const qreal w = scale * size;
    const qreal h = w * photo.height() / photo.width();
    // Scaled once, smoothly, then drawn: far better than scaling while drawing.
    const QImage fg = photo.scaled(qMax(1, qRound(w)), qMax(1, qRound(h)), Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    QPainter p(&out);
    p.drawImage(QPointF(cx * size - w / 2, cy * size - h / 2), fg);
    p.end();
    return out;
}

QString Composer::previewBackground(const QString &source, int size, const QVariantMap &layout)
{
    const int rotation = layout.value(QStringLiteral("rotation")).toInt();
    const QString key = QStringLiteral("%1|%2|%3").arg(source).arg(rotation).arg(size);
    if (key != m_previewKey) {
        // A small photo is plenty for a small background.
        const QImage photo = load(source, rotation);
        if (photo.isNull())
            return QString();
        m_previewPhoto = photo.scaled(size * 2, size * 2, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        m_previewKey = key;
    }
    const QImage bg = background(m_previewPhoto, qBound(64, size, 2048), layout);
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(dir);
    // The last one is removed: only one preview is kept.
    if (m_previewCount > 0)
        QFile::remove(QStringLiteral("%1/preview-%2.png").arg(dir).arg(m_previewCount));
    const QString path = QStringLiteral("%1/preview-%2.png").arg(dir).arg(++m_previewCount);
    if (!bg.save(path, "PNG"))
        return QString();
    return QUrl::fromLocalFile(path).toString();
}

QVariantMap Composer::render(const QString &source, const QVariantMap &layout, const QString &target) const
{
    QVariantMap out;
    QString error;
    const QImage photo = load(source, layout.value(QStringLiteral("rotation")).toInt(), &error);
    if (photo.isNull()) {
        out.insert(QStringLiteral("ok"), false);
        out.insert(QStringLiteral("error"), QStringLiteral("The photo couldn't be read: ") + error);
        return out;
    }
    const QImage image = compose(photo, layout);
    const QString path = localPath(target);
    QDir().mkpath(QFileInfo(path).absolutePath());
    const bool png = path.endsWith(QLatin1String(".png"), Qt::CaseInsensitive);
    if (!image.save(path, png ? "PNG" : "JPEG", png ? -1 : 95)) {
        out.insert(QStringLiteral("ok"), false);
        out.insert(QStringLiteral("error"), QStringLiteral("The image couldn't be saved to ") + path);
        return out;
    }
    out.insert(QStringLiteral("ok"), true);
    out.insert(QStringLiteral("path"), path);
    out.insert(QStringLiteral("width"), image.width());
    out.insert(QStringLiteral("height"), image.height());
    return out;
}

void Composer::save(const QString &source, const QVariantMap &layout)
{
    if (m_busy)
        return;
    m_busy = true;
    emit busyChanged();
    const QString target = QStringLiteral("%1/AmbienceCrop-%2.jpg")
            .arg(m_outputDir, QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss")));
    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(watcher, &QFutureWatcher<QVariantMap>::finished, this, [this, watcher]() {
        const QVariantMap result = watcher->result();
        watcher->deleteLater();
        m_busy = false;
        emit busyChanged();
        emit saved(result.value(QStringLiteral("path")).toString(), result.value(QStringLiteral("error")).toString());
    });
    watcher->setFuture(QtConcurrent::run([this, source, layout, target]() {
        return render(source, layout, target);
    }));
}

void Composer::createAmbience(const QString &path, bool makeCurrent)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        // Reported from the event loop, like an answer would be.
        const QString error = QStringLiteral("the phone's session bus isn't reachable (") + bus.lastError().message() + QLatin1Char(')');
        QMetaObject::invokeMethod(this, "ambienceDone", Qt::QueuedConnection, Q_ARG(qlonglong, -1), Q_ARG(QString, error));
        return;
    }
    QDBusMessage call = QDBusMessage::createMethodCall(
                QStringLiteral("com.jolla.ambienced"), QStringLiteral("/com/jolla/ambienced"),
                QStringLiteral("com.jolla.ambienced"),
                makeCurrent ? QStringLiteral("setAmbience") : QStringLiteral("createAmbience"));
    call << QUrl::fromLocalFile(localPath(path)).toString();
    auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(call, m_ambienceTimeout), this);
    auto answer = [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<qlonglong> reply = *w;
        w->deleteLater();
        if (reply.isError())
            emit ambienceDone(-1, reply.error().message().isEmpty() ? reply.error().name() : reply.error().message());
        else
            emit ambienceDone(reply.value(), QString());
    };
    // A call that failed at once (refused, say) is finished already, and
    // Qt 5.6 then never emits finished(): answer it from the event loop.
    if (watcher->isFinished())
        QTimer::singleShot(0, this, [watcher, answer]() { answer(watcher); });
    else
        connect(watcher, &QDBusPendingCallWatcher::finished, this, answer);
}

QVariantMap Composer::pixelAt(const QString &path, qreal x, qreal y) const
{
    QVariantMap out;
    const QImage image(localPath(path));
    if (image.isNull())
        return out;
    const QRgb p = image.pixel(qBound(0, int(x * image.width()), image.width() - 1),
                               qBound(0, int(y * image.height()), image.height() - 1));
    out.insert(QStringLiteral("red"), qRed(p));
    out.insert(QStringLiteral("green"), qGreen(p));
    out.insert(QStringLiteral("blue"), qBlue(p));
    out.insert(QStringLiteral("width"), image.width());
    out.insert(QStringLiteral("height"), image.height());
    return out;
}

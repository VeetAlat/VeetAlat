#ifndef COMPOSER_H
#define COMPOSER_H

#include <QImage>
#include <QObject>
#include <QString>
#include <QVariantMap>

// Makes ambience images: a square (2048 x 2048 by default, what Sailfish
// ambiences use) with the photo placed where the user put it, and the
// rest filled with a blurred, darkened copy of the photo, its average
// colour, or black. The portrait and landscape screens each show a
// rectangle centred in the square; the corners are never seen.
//
// A layout is { size, cx, cy, scale, rotation, background, blur, dim }:
// the photo's centre (cx, cy) and width (scale) are fractions of the
// square's side, rotation is 0, 90, 180 or 270 degrees on top of the
// photo's own EXIF orientation, background is "blur", "colour" or
// "black", and blur and dim go from 0 to 1.
class Composer : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString outputDir READ outputDir WRITE setOutputDir NOTIFY outputDirChanged)
    // How long to wait for the ambience service (making an ambience
    // processes the picture, so it can take a few seconds).
    Q_PROPERTY(int ambienceTimeout MEMBER m_ambienceTimeout NOTIFY ambienceTimeoutChanged)

public:
    explicit Composer(QObject *parent = nullptr);

    bool busy() const { return m_busy; }
    QString outputDir() const { return m_outputDir; }
    void setOutputDir(const QString &dir);

    // { ok, width, height, error }: the photo's size as shown (EXIF applied).
    Q_INVOKABLE QVariantMap inspect(const QString &source) const;
    // The background alone at a small size, for the editor's preview: a
    // file URL (a new name each time, so QML reloads it), or "".
    Q_INVOKABLE QString previewBackground(const QString &source, int size, const QVariantMap &layout);
    // Renders to target now: { ok, path, width, height, error }.
    Q_INVOKABLE QVariantMap render(const QString &source, const QVariantMap &layout, const QString &target) const;
    // Renders into outputDir in the background, then emits saved().
    Q_INVOKABLE void save(const QString &source, const QVariantMap &layout);
    // Asks ambienced to make an ambience of the image (createAmbience), or
    // to make one and switch to it (setAmbience); emits ambienceDone().
    Q_INVOKABLE void createAmbience(const QString &path, bool makeCurrent);
    // For the tests: { red, green, blue, width, height } at (x, y) as fractions.
    Q_INVOKABLE QVariantMap pixelAt(const QString &path, qreal x, qreal y) const;

    static QImage load(const QString &source, int rotation, QString *error = nullptr);
    static QImage compose(const QImage &photo, const QVariantMap &layout);
    static QImage background(const QImage &photo, int size, const QVariantMap &layout);
    static void boxBlur(QImage &image, int radius);

signals:
    void busyChanged();
    void outputDirChanged();
    void ambienceTimeoutChanged();
    void saved(const QString &path, const QString &error);
    void ambienceDone(qlonglong contentId, const QString &error);

private:
    bool m_busy = false;
    int m_ambienceTimeout = 30000;
    QString m_outputDir;
    int m_previewCount = 0;
    // A small copy of the photo for previews, so sliders don't decode the
    // whole photo again each time.
    QString m_previewKey;
    QImage m_previewPhoto;
};

#endif

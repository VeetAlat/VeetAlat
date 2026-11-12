# AmbienceCrop for Sailfish OS

Frame a photo for a Sailfish **ambience** exactly the way you want it.

Sailfish ambiences use a **square** picture (2048 × 2048), and the phone
only shows the middle of it: a tall strip when you hold the phone upright,
a wide one when you turn it. The corners are never seen. So when you make
an ambience from a photo, Settings crops it to a square, and the part you
cared about often ends up cut off.

AmbienceCrop lets you put the photo on that square yourself. You see the
exact frames the phone will show, and the rest of the square is filled
with a soft blur of the photo (or its colour, or black). Then it saves the
picture and makes the ambience.

Made by Valatalo.

## How it works

1. **Choose a photo:** from the gallery, or by browsing files. JPEG and
   PNG both work, and phone photos come out the right way up (their EXIF
   orientation is used).
2. **Frame it** on the square:
   - **Drag** to move, **pinch** to zoom, and **double-tap** to switch
     between filling the screen and showing the whole photo.
   - **The white frame** is what the phone shows held upright. **The
     dashed lines** mark what it shows turned sideways. You can shade
     around either one, or show a profile photo's circle instead.
   - **Ready-made placements:** *Fill screen* (the default), *Whole
     photo*, *Fill square*, *Fill sideways*, *Centre* and *Turn ↻*.
   - **Around the photo:** a *blurred* copy of it (blur and darkening
     adjustable), *its colour*, or *black*.
   - **The header says what the screens will show:** the photo filling
     both, or the blur showing when the phone is turned.
3. **Save:**
   - **Where it goes:** a 2048 × 2048 JPEG (larger if the screen is
     taller) in `Pictures/AmbienceCrop`.
   - **Make an ambience** hands it to the phone's ambience service, the
     same one the Gallery's ambience button uses. **Make it and use it
     now** also switches to it.
   - Name the ambience and choose its colours and sounds in Settings →
     Ambience.

The square pictures also make good profile photos: there's a circle guide
for that.

## Inside

- **`src/composer.cpp`** does the image work with `QImage`:
  - EXIF-aware loading;
  - the background, scaled to cover the square, blurred and darkened (a
    three-pass box blur on a smaller copy, scaled back up: fast and
    smooth);
  - the photo drawn smoothly where it was placed;
  - a JPEG at quality 95, made off the screen's thread;
  - the D-Bus call to `com.jolla.ambienced` (`createAmbience` or
    `setAmbience`).
- **`qml/js/layout.js`** holds the placement maths shared by the editor
  and the tests. The editor's preview uses the same composer at a small
  size, so what you see is what you get.
- **Sailjail permissions:**
  - `Pictures` and `Downloads`: to read the photo and save the result;
  - `MediaIndexing`: so the gallery picker can list photos;
  - `Ambience`: to talk to the ambience service.

## Building and installing

```sh
./build-rpm.sh aarch64      # Docker; RPM lands in RPMS/
devel-su pkcon install-local ~/Downloads/ambiencecrop-0.1.0-1.aarch64.rpm
```

## Tests

```sh
node tests/test_layout.js     # the placement maths: 27 checks
tests/sdk-smoke-test.sh       # the app end to end in the Sailfish SDK (Docker): 38 checks
```

The smoke test runs the real app on Sailfish's Qt 5.6 and Silica, and
checks pixels of what the composer makes from the test photos in
`tests/fixtures` (made by `tests/make-fixtures.py`):
- the photo lands where it was placed;
- the blur, darkening, average-colour and black backgrounds;
- an EXIF-turned phone photo comes out upright;
- *Turn* works.

Then it opens the editor and checks its presets and preview. It saves
through the real Save button's path and checks the picture. Last, it
checks that making an ambience without an ambience service (the SDK has
none) says so cleanly.

## Made with AI-assisted tools

This app has been created using AI generated code (Claude code).

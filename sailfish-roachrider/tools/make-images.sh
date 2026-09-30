#!/bin/sh
#
# Makes every picture the app ships, on the build machine: the roach
# renders (from tools/roach.obj), the icon in all sizes and the game
# buttons. The results are committed, so the RPM build needs none of this.
# Needs Qt 5 (qmake), python3 and rsvg-convert.

set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT
export QT_QPA_PLATFORM=offscreen

(cd "$BUILD" && qmake "$HERE/tools/roach-render/roach-render.pro" > /dev/null && make -j"$(nproc)" > /dev/null)
render() { "$BUILD/roach-render" "$HERE/tools/roach.obj" "$@" 2> /dev/null; }

mkdir -p "$HERE/qml/images"
# In the game, from behind and a little above, like the game's camera.
render "$HERE/qml/images/roach-back.png" 384 0 15 1
# The start screen: turned three quarters towards you.
render "$HERE/qml/images/roach-menu.png" 720 215 14 1
# The icon: facing you.
render "$BUILD/roach-front.png" 512 198 8 1

cd "$HERE"
python3 icons/make-icon.py "$BUILD/roach-front.png"
for s in 86 108 128 172; do
    mkdir -p "icons/${s}x$s"
    rsvg-convert -w $s -h $s icons/roachrider.svg -o "icons/${s}x$s/roachrider.png"
done

python3 icons/make-buttons.py "$BUILD/buttons" > /dev/null
for f in "$BUILD"/buttons/*.svg; do
    rsvg-convert -w 300 -h 300 "$f" -o "qml/images/$(basename "$f" .svg).png"
done
echo "images made"

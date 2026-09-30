#!/bin/sh
#
# Screenshots of the real renderer in set situations (start, riding,
# blocks, a jump, a corner, riding the wall, each colour), on the build
# machine's Qt and a virtual display. Usage: tests/render-screens.sh [out-dir]

set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(realpath -m "${1:-screens}")
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT
cd "$BUILD"
qmake "$HERE/render/render.pro" > /dev/null
make -j"$(nproc)" > /dev/null
xvfb-run -a -s "-screen 0 1280x1400x24" ./render "$OUT" 2>&1 | grep -v XDG_RUNTIME_DIR
echo "screenshots in $OUT"

#!/bin/sh
#
# Game rules and track tests, on the build machine's Qt (5.15 is fine).
# Includes a bot with perfect reactions riding 2500 rows of a dozen
# different tracks, to show every track the game builds can be ridden.

set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT
cd "$BUILD"
qmake "$HERE/game/game.pro" > /dev/null
make -j"$(nproc)" > /dev/null
./tst_game

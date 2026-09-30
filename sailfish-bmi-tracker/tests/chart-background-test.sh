#!/bin/sh
#
# Regression test for "the graph is missing after going to the home screen
# and back". Sailfish frees an app's GL context and scene graph in the
# background; a QML Canvas then comes back blank unless it repaints.
# This renders the real history chart on a virtual display with those
# freed on hide (like the phone), hides and shows the window, and checks
# the chart looks the same afterwards. Uses the desktop Qt 5 and Xvfb; the
# Silica bits the chart needs are stubbed in tests/background/stubs.

set -eu

HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp -r "$HERE/tests/background/." "$WORK/"
mkdir -p "$WORK/qml"
cp -r "$HERE/qml/components" "$HERE/qml/js" "$WORK/qml/"
cp "$WORK/ChartCycle.qml" "$WORK/qml/"

(cd "$WORK" && qmake cycle.pro > /dev/null && make -s > /dev/null)
xvfb-run -a -s "-screen 0 1280x1100x24 +extension GLX" \
    "$WORK/cycle" "$WORK/stubs" "$WORK/qml/ChartCycle.qml" \
    "$WORK/before.png" "$WORK/after.png" 2>&1 | grep -E "^(before|after):" || true

if cmp -s "$WORK/before.png" "$WORK/after.png"; then
    echo "PASS: the chart is still drawn after going to the background and back"
else
    echo "FAIL: the chart looks different (blank?) after going to the background and back"
    exit 1
fi

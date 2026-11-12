#!/bin/sh
#
# Lays out StatusArea's bar (patches/statusbar/NotchStatusBar.qml) in the
# Sailfish SDK, over notches of several sizes, with a stand-in for the home
# screen's status area built like the real one. Checks the clock and the
# icons never overlap each other or the notch. Needs Docker.

set -eu

SDK_VERSION=4.6.0.13
TARGET=SailfishOS-$SDK_VERSION-i486
HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp -r "$HERE/tests/bar/." "$WORK/"
sed 's|import "file:///usr/share/lipstick-jolla-home-qt5/statusarea"|import "fake"|' \
    "$HERE/patches/statusbar/NotchStatusBar.qml" > "$WORK/NotchStatusBar.qml"
grep -q 'import "fake"' "$WORK/NotchStatusBar.qml"
cp "$HERE/patches/statusbar/CompactBattery.qml" "$WORK/"
# A copy whose compact battery can't load, to check the original stays.
mkdir "$WORK/broken"
sed 's|import "fake"|import "../fake"|' "$WORK/NotchStatusBar.qml" > "$WORK/broken/NotchStatusBar.qml"
echo 'this is not QML' > "$WORK/broken/CompactBattery.qml"
chmod -R a+rwX "$WORK"

docker run --rm -v "$WORK:/home/mersdk/bar" -w /home/mersdk/bar \
    "coderus/sailfishos-platform-sdk:$SDK_VERSION" bash -c "
        QML2_IMPORT_PATH=/home/mersdk/bar/stub QT_QPA_PLATFORM=\${QT_QPA_PLATFORM:-minimal} \
            sb2 -t $TARGET sh -c 'g++ -o runner runner.cpp /usr/lib/libQt5QuickTest.so.5 && ./runner -input tst_barlayout.qml' 2>&1 |
            grep -v -E 'dconf|pixel ratio|DPI'
    " | tee "$WORK/out.log"
# Expected here: no system D-Bus for the battery's sources, and the broken
# copy's own error. Any other warning fails the test.
grep -q "Totals: .* 0 failed" "$WORK/out.log" &&
    ! grep -E "QWARN|qml: .*(Error|rror:)|TypeError|ReferenceError" "$WORK/out.log" |
        grep -v -E "org\.nemomobile\.dbus: |broken/CompactBattery\.qml:1:1: Expected a qualified name id" | grep -q .

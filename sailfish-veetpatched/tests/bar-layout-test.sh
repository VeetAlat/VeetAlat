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
for f in "$HERE"/patches/statusbar/*.qml; do
    [ "$(basename "$f")" = NotchStatusBar.qml ] || cp "$f" "$WORK/"
done
chmod -R a+rwX "$WORK"

docker run --rm -v "$WORK:/home/mersdk/bar" -w /home/mersdk/bar \
    "coderus/sailfishos-platform-sdk:$SDK_VERSION" bash -c "
        QML2_IMPORT_PATH=/home/mersdk/bar/stub QT_QPA_PLATFORM=\${QT_QPA_PLATFORM:-minimal} \
            sb2 -t $TARGET sh -c 'g++ -o runner runner.cpp /usr/lib/libQt5QuickTest.so.5 && ./runner -input tst_barlayout.qml' 2>&1 |
            grep -v -E 'dconf|pixel ratio|DPI'
    " | tee "$WORK/out.log"
# Expected here: StatusBar's report (checked below), the broken test
# source's own error, and the real battery sources finding no D-Bus in the
# SDK. Any other warning fails the test.
grep -q "Totals: .* 0 failed" "$WORK/out.log" &&
    ! grep -E "QWARN|qml: .*(Error|rror:)|TypeError|ReferenceError" "$WORK/out.log" |
        grep -v -E "VeetPatched StatusBar: |Broken\.qml:1:1: Expected a qualified name id|org\.nemomobile\.dbus: |[Mm]ce" | grep -q . &&
    grep -q "test_report() qml: VeetPatched StatusBar: screen 560, notch 200+160x40, battery from FakeBattery (tried: NoCharge gave no charge); left: room 148, needs [0-9]*, scale 1.00; right icons found, .* (started [0-9:]*)" "$WORK/out.log"

#!/bin/bash
# Runs the real QML pages + Python bridge against stub Silica components and the fake crosvm.
# Needs: qmlscene, qml-module-io-thp-pyotherside, xorriso (for the test ISO).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
WORK=$(mktemp -d)
trap 'pkill -f "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

# app tree as installed, minus attached properties that cannot be stubbed in QML (EnterKey)
mkdir -p "$WORK/app"
cp -r "$ROOT/src/qml" "$WORK/app/qml"
cp -r "$ROOT/src/python" "$WORK/app/python"
sed -i -e '/EnterKey\.iconSource/d' \
    -e 's/EnterKey\.onClicked: {$/property var enterKeyClicked: function() {/' \
    -e 's/EnterKey\.onClicked: \(.*[^{]\)$/property var enterKeyClicked: function() { \1 }/' \
    "$WORK"/app/qml/pages/*.qml

# test ISO with an Ubuntu-like layout
mkdir -p "$WORK/isoroot/casper"
python3 - "$WORK/isoroot/casper/vmlinuz" <<'EOF'
import gzip, sys
img = bytearray(4096); img[56:60] = b"ARM\x64"
open(sys.argv[1], "wb").write(gzip.compress(bytes(img)))
EOF
echo initrd > "$WORK/isoroot/casper/initrd"
xorriso -as mkisofs -quiet -R -V "Ubuntu 24.04 arm64" -o /tmp/sailvisor-ui-test.iso "$WORK/isoroot" 2>/dev/null

mkdir -p "$WORK/share/guest"
echo kernel > "$WORK/share/guest/Image"
echo initrd > "$WORK/share/guest/initrd.img"
export SAILVISOR_DATA=$WORK/data SAILVISOR_SHARE=$WORK/share SAILVISOR_CROSVM=$ROOT/tests/fake-crosvm SAILVISOR_GZVM=/dev/null
export QML2_IMPORT_PATH=$HERE/stubs QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software

timeout 180 qmlscene "$WORK/app/qml/sailvisor.qml" --ui-test > "$WORK/out.log" 2>&1
grep -E "UITEST (PASS|FAIL|DONE)" "$WORK/out.log"
echo "--- QML warnings/errors ---"
grep -vE "UITEST|STUB: pushed|sailvisor: backend ready|^qml: $" "$WORK/out.log" | grep -iE "warn|error|undefined|cannot|unable|TypeError|ReferenceError|failed" || echo "(none)"
grep -q "UITEST DONE failures=0" "$WORK/out.log" || { echo "--- full log (tail) ---"; tail -40 "$WORK/out.log"; exit 1; }

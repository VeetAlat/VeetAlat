#!/bin/sh
#
# End-to-end smoke test in the Sailfish SDK (Docker), against Sailfish's
# own Qt 5.6 and Silica. Builds a copy of the app with tests/SmokeTest.qml
# injected, starts it twice (the second start must see what the first
# saved), and fails on any failed check or any QML warning.
#
# There's no GPU in the SDK container, so the window itself can't be
# shown; the test builds the pages directly, the same way the app does.

set -eu

SDK_VERSION=4.6.0.13
TARGET=SailfishOS-$SDK_VERSION-i486
HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp -r "$HERE" "$WORK/app"
rm -rf "$WORK/app/RPMS" "$WORK/app/Makefile" "$WORK/app"/*.o "$WORK/app"/moc_*
cp "$HERE/tests/SmokeTest.qml" "$WORK/app/qml/SmokeTest.qml"
# Add the test object as the main window's last child.
python3 - "$WORK/app/qml/harbour-bmitracker.qml" <<'EOF'
import sys
path = sys.argv[1]
s = open(path).read().rstrip()
assert s.endswith("}")
s = s[:-1] + "\n    SmokeTest { testedWindow: app; testedStore: appStore }\n}\n"
open(path, "w").write(s)
EOF
chmod -R a+rwX "$WORK"

docker run --rm -v "$WORK/app:/home/mersdk/src" -w /home/mersdk/src \
    "coderus/sailfishos-platform-sdk:$SDK_VERSION" bash -c "
        mb2 -t $TARGET build > build.log 2>&1 || { tail -30 build.log; exit 1; }
        sb2 -t $TARGET -m sdk-install -R rpm -i --nodeps --force RPMS/*.i486.rpm > /dev/null 2>&1
        for run in 1 2; do
            QT_LOGGING_TO_CONSOLE=1 QT_QPA_PLATFORM=minimal timeout 15 \
                sb2 -t $TARGET /usr/bin/harbour-bmitracker 2>&1 |
                grep -v -E 'dconf|pixel ratio|DPI|OpenGL|createPlatformOpenGL|Exit reason|^\$' || true
        done" > "$WORK/out.log" 2>&1

cat "$WORK/out.log"
echo
passes=$(grep -c "SMOKE PASS" "$WORK/out.log" || true)
fails=$(grep -c "SMOKE FAIL" "$WORK/out.log" || true)
runs=$(grep -c "SMOKE DONE" "$WORK/out.log" || true)
warnings=$(grep -v "SMOKE" "$WORK/out.log" | grep -c -E "qml|Error|Warning|warning|unavailable|Binding loop" || true)

echo "passed: $passes, failed: $fails, runs completed: $runs/2, QML warnings: $warnings"
[ "$fails" -eq 0 ] && [ "$runs" -eq 2 ] && [ "$warnings" -eq 0 ] && [ "$passes" -gt 0 ]

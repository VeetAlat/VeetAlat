#!/bin/sh
#
# End-to-end smoke test in the Sailfish SDK (Docker), against Sailfish's
# own Qt 5.6 and Silica. Builds a copy of the app with tests/SmokeTest.qml
# injected, starts it twice (the second start must see what the first
# saved), and fails on any failed check or any QML warning.
#
# There's no GPU in the SDK container, so nothing can be drawn: the test
# copy never shows its window. The pages, the game and its loop all run as
# usual. tests/render-screens.sh covers the drawing, on the build machine.
# Without a window, Silica's own cover window warns about a missing Config;
# that warning is left out.

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
python3 - "$WORK/app/qml/roachrider.qml" <<'EOF'
import sys
path = sys.argv[1]
s = open(path).read().rstrip()
assert s.endswith("}")
s = s[:-1] + "\n    SmokeTest { testedWindow: app }\n}\n"
open(path, "w").write(s)
EOF
# No window: the SDK can't draw it (see above).
sed -i 's/    view->show();/    \/\/ view->show();/' "$WORK/app/src/main.cpp"
grep -q '// view->show();' "$WORK/app/src/main.cpp"
chmod -R a+rwX "$WORK"

docker run --rm -v "$WORK/app:/home/mersdk/src" -w /home/mersdk/src \
    "coderus/sailfishos-platform-sdk:$SDK_VERSION" bash -c "
        mb2 -t $TARGET build > build.log 2>&1 || { tail -30 build.log; exit 1; }
        sb2 -t $TARGET -m sdk-install -R rpm -i --nodeps --force RPMS/*.i486.rpm > /dev/null 2>&1
        for run in 1 2; do
            QT_LOGGING_TO_CONSOLE=1 QT_QPA_PLATFORM=minimal timeout 150 \
                sb2 -t $TARGET /usr/bin/roachrider 2>&1 |
                grep -v -E 'dconf|pixel ratio|DPI|OpenGL|createPlatformOpenGL|Exit reason|^\$' |
                grep -v -E 'Silica/private/CoverWindow.qml:1[01]: ReferenceError: Config is not defined' || true
        done" > "$WORK/out.log" 2>&1

cat "$WORK/out.log"
echo
passes=$(grep -c "SMOKE PASS" "$WORK/out.log" || true)
fails=$(grep -c "SMOKE FAIL" "$WORK/out.log" || true)
runs=$(grep -c "SMOKE DONE" "$WORK/out.log" || true)
warnings=$(grep -v "SMOKE" "$WORK/out.log" | grep -c -E "qml|Error|Warning|warning|unavailable|Binding loop" || true)

echo "passed: $passes, failed: $fails, runs completed: $runs/2, QML warnings: $warnings"
[ "$fails" -eq 0 ] && [ "$runs" -eq 2 ] && [ "$warnings" -eq 0 ] && [ "$passes" -gt 0 ]

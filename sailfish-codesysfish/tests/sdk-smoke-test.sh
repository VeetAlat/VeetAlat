#!/bin/sh
#
# End-to-end smoke test in the Sailfish SDK (Docker), against Sailfish's
# own Qt 5.6 and Silica. Builds a copy of the app with tests/SmokeTest.qml
# injected, runs it twice without a window (the SDK has no GPU), and fails
# on any failed check or QML warning.
#
# Each run ends with "Exit reason and status: signal 11". That's Silica's
# cover machinery without the phone's home screen: the smallest possible
# Silica app with one CoverAction crashes the same way on quit here.
# Runs are therefore counted by their "SMOKE DONE" line, not the exit status.

set -eu

SDK_VERSION=4.6.0.13
TARGET=SailfishOS-$SDK_VERSION-i486
HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp -r "$HERE" "$WORK/app"
rm -rf "$WORK/app/RPMS" "$WORK/app/Makefile" "$WORK/app"/*.o "$WORK/app"/moc_* "$WORK/app/.mb2"
cp "$HERE/tests/SmokeTest.qml" "$WORK/app/qml/SmokeTest.qml"
python3 - "$WORK/app/qml/codesysfish.qml" <<'PY'
import sys
path = sys.argv[1]
s = open(path).read().rstrip()
assert s.endswith("}")
s = s[:-1] + "\n    SmokeTest { testedWindow: app; testedPlc: thePlc }\n}\n"
open(path, "w").write(s)
PY
chmod -R a+rwX "$WORK"

docker run --rm -v "$WORK/app:/home/mersdk/src" -w /home/mersdk/src \
    "coderus/sailfishos-platform-sdk:$SDK_VERSION" bash -c "
        mb2 -t $TARGET build > build.log 2>&1 || { tail -30 build.log; exit 1; }
        grep -E 'warning:' build.log | grep -v 'Wno-' | head -20 || true
        sb2 -t $TARGET -m sdk-install -R rpm -i --nodeps --force RPMS/*.i486.rpm > /dev/null 2>&1
        for run in 1 2; do
            CODESYSFISH_NO_WINDOW=1 QT_LOGGING_TO_CONSOLE=1 QT_QPA_PLATFORM=minimal timeout 60 \
                sb2 -t $TARGET /usr/bin/codesysfish 2>&1 |
                grep -v -E 'dconf|pixel ratio|DPI|^\$' || true
        done" > "$WORK/out.log" 2>&1

cat "$WORK/out.log"
echo
passes=$(grep -c "SMOKE PASS" "$WORK/out.log" || true)
fails=$(grep -c "SMOKE FAIL" "$WORK/out.log" || true)
runs=$(grep -c "SMOKE DONE" "$WORK/out.log" || true)
# Silica's cover window needs the phone's home screen (lipstick) for its
# Config object, so it complains when there's no window; that one file is
# Sailfish's, not ours, and is left out. Everything else counts, compiler
# warnings from our C++ included.
warnings=$(grep -v "SMOKE" "$WORK/out.log" | grep -v "Sailfish/Silica/private/CoverWindow.qml" |
    grep -c -E "qml|Error|Warning|warning|unavailable|Binding loop" || true)

echo "passed: $passes, failed: $fails, runs completed: $runs/2, warnings: $warnings"
[ "$fails" -eq 0 ] && [ "$runs" -eq 2 ] && [ "$warnings" -eq 0 ] && [ "$passes" -gt 0 ]

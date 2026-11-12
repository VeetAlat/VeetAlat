#!/bin/sh
#
# End-to-end test in the Sailfish SDK (Docker): the real app and the real
# root helper together. systemd doesn't run in the SDK, so a loop stands
# in for veetpatched.path: whenever the app writes a request, it runs the
# installed helper's "serve", on a copy of the home screen's AppLayer.qml
# (5.2's layout). Afterwards that file must be the original again.
#
# The run ends with "Exit reason and status: signal 11": Silica's cover
# machinery without the phone's home screen. Runs are counted by their
# "SMOKE DONE" line instead.

set -eu

SDK_VERSION=4.6.0.13
TARGET=SailfishOS-$SDK_VERSION-i486
HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp -r "$HERE" "$WORK/app"
rm -rf "$WORK/app/RPMS" "$WORK/app/Makefile" "$WORK/app"/*.o "$WORK/app"/moc_* "$WORK/app/.mb2"
cp "$HERE/tests/SmokeTest.qml" "$WORK/app/qml/SmokeTest.qml"
python3 - "$WORK/app/qml/veetpatched.qml" <<'PY'
import sys
path = sys.argv[1]
s = open(path).read().rstrip()
assert s.endswith("}")
s = s[:-1] + "\n    SmokeTest { testedWindow: app; testedPatcher: thePatcher }\n}\n"
open(path, "w").write(s)
PY
chmod -R a+rwX "$WORK"

docker run --rm -v "$WORK/app:/home/mersdk/src" -w /home/mersdk/src \
    "coderus/sailfishos-platform-sdk:$SDK_VERSION" bash -c "
        mb2 -t $TARGET build > build.log 2>&1 || { tail -30 build.log; exit 1; }
        grep -E 'warning:' build.log | grep -v 'Wno-' | head -20 || true
        sb2 -t $TARGET -m sdk-install -R rpm -i --nodeps --force --noscripts RPMS/*.i486.rpm > /dev/null 2>&1
        # A copy of the home screen file, and the stand-in for veetpatched.path.
        FAKE=/home/mersdk/fake
        mkdir -p \$FAKE/usr/share/lipstick-jolla-home-qt5/layers /home/mersdk/vpstate
        cp tests/fixtures/AppLayer-5.2.qml \$FAKE/usr/share/lipstick-jolla-home-qt5/layers/AppLayer.qml
        OUT=/home/mersdk/.local/share/org.veetalat/veetpatched
        mkdir -p \$OUT
        # A home screen that started long before the patch file was copied.
        PROC=/home/mersdk/fakeproc
        mkdir -p \$PROC/4242
        printf 'btime %s\\n' \$(( \$(date +%s) - 1000 )) > \$PROC/stat
        echo lipstick > \$PROC/4242/comm
        echo '4242 (lipstick) S 1 1 1 0 -1 0 0 0 0 0 0 0 0 0 20 0 1 0 100 0 0' > \$PROC/4242/stat
        sb2 -t $TARGET sh -c \"while true; do [ -e \$OUT/request ] && VP_PROC=\$PROC VP_ROOT=\$FAKE VP_STATE=/home/mersdk/vpstate VP_OUT=\$OUT VP_USER=mersdk /usr/libexec/veetpatched/veetpatched-helper serve; sleep 0.2; done\" &
        WATCH=\$!
        VEETPATCHED_NO_WINDOW=1 QT_LOGGING_TO_CONSOLE=1 QT_QPA_PLATFORM=minimal timeout 120 \
            sb2 -t $TARGET /usr/bin/veetpatched 2>&1 | grep -v -E 'dconf|pixel ratio|DPI|^\$' || true
        kill \$WATCH 2>/dev/null || true
        if cmp -s tests/fixtures/AppLayer-5.2.qml \$FAKE/usr/share/lipstick-jolla-home-qt5/layers/AppLayer.qml; then
            echo 'SMOKE PASS the home screen file is the original again, byte for byte'
        else
            echo 'SMOKE FAIL the home screen file is the original again, byte for byte'
        fi
        echo '--- helper log'; cat /home/mersdk/vpstate/log" > "$WORK/out.log" 2>&1

cat "$WORK/out.log"
echo
passes=$(grep -c "SMOKE PASS" "$WORK/out.log" || true)
fails=$(grep -c "SMOKE FAIL" "$WORK/out.log" || true)
runs=$(grep -c "SMOKE DONE" "$WORK/out.log" || true)
warnings=$(sed '/^--- helper log/,$d' "$WORK/out.log" | grep -v "SMOKE" | grep -v "Sailfish/Silica/private/CoverWindow.qml" |
    grep -c -E "qml|Error|Warning|warning|unavailable|Binding loop" || true)

echo "passed: $passes, failed: $fails, runs completed: $runs/1, warnings: $warnings"
[ "$fails" -eq 0 ] && [ "$runs" -eq 1 ] && [ "$warnings" -eq 0 ] && [ "$passes" -gt 0 ]

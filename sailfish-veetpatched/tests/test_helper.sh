#!/bin/sh
# Tests for helper/veetpatched-helper, on copies of the home screen's
# AppLayer.qml (Sailfish 4.6's, and 5.2's layout from the phone).
# Run: sh tests/test_helper.sh   (also runs in the SDK target, on its tools)

HERE=$(cd "$(dirname "$0")/.." && pwd)
H="$HERE/helper/veetpatched-helper"
FIX="$HERE/tests/fixtures"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
check() {
    if [ "$2" = 0 ]; then echo "ok   - $1"; PASS=$((PASS + 1)); else echo "FAIL - $1"; FAIL=$((FAIL + 1)); fi
}
fresh() {   # fresh <fixture>: a new root with that AppLayer.qml
    rm -rf "$W/root" "$W/state" "$W/out"
    mkdir -p "$W/root/usr/share/lipstick-jolla-home-qt5/layers" "$W/state" "$W/out"
    cp "$FIX/$1" "$W/root/usr/share/lipstick-jolla-home-qt5/layers/AppLayer.qml"
    cp "$FIX/$1" "$W/original"
}
T="$W/root/usr/share/lipstick-jolla-home-qt5/layers/AppLayer.qml"
export VP_ROOT="$W/root" VP_PATCHES="$HERE/patches" VP_STATE="$W/state" VP_OUT="$W/out" VP_USER="$(id -un)" VP_SYSLOG=0
run() { sh "$H" "$@"; }

for f in AppLayer-4.6.qml AppLayer-5.2.qml AppLayer-no-final-newline.qml AppLayer-crlf.qml; do
    fresh "$f"
    [ "$(run status)" = "patch statusbar not-applied" ]; check "$f: starts not applied" $?
    [ "$(run apply statusbar)" = "applied" ]; check "$f: applies" $?
    grep -q 'VEETPATCHED:statusbar:begin' "$T" && grep -q 'source: "file:///usr/share/veetpatched/patches/statusbar/NotchStatusBar.qml"' "$T"
    check "$f: the Loader is in, between markers" $?
    # It goes just before the last closing brace: the file still ends with "}".
    [ "$(tail -n 1 "$T" | tr -d '\r\n')" = "}" ] && [ "$(grep -c 'VEETPATCHED:statusbar:end' "$T")" = 1 ]
    check "$f: inside the StackLayer, before its closing brace" $?
    cp "$T" "$W/once"
    [ "$(run apply statusbar)" = "applied" ] && cmp -s "$T" "$W/once"; check "$f: applying twice changes nothing" $?
    [ "$(run status)" = "patch statusbar applied" ]; check "$f: status says applied" $?
    [ "$(run unapply statusbar)" = "not-applied" ]; check "$f: unapplies" $?
    cmp -s "$T" "$W/original"; check "$f: the original back, byte for byte" $?
    [ "$(run unapply statusbar)" = "not-applied" ] && cmp -s "$T" "$W/original"; check "$f: unapplying twice changes nothing" $?
done

# The patched file has exactly the lines it should: the original, plus the block.
fresh AppLayer-4.6.qml
run apply statusbar > /dev/null
[ $(wc -l < "$T") -eq $(( $(wc -l < "$W/original") + $(wc -l < "$HERE/patches/statusbar/block.qml") + 2 )) ]
check "only the block and its two markers are added" $?

# The wrong file, or none.
fresh AppLayer-4.6.qml
sed -i 's/id: appLayer/id: somethingElse/' "$T"; cp "$T" "$W/before"
out=$(run apply statusbar); [ "${out%% *}" = "failed" ] && cmp -s "$T" "$W/before"; check "the wrong file is refused and left alone" $?
rm "$T"
out=$(run apply statusbar); [ "${out%% *}" = "failed" ] && [ ! -e "$T" ]; check "a missing file is reported, nothing created" $?
[ "$(run status)" = "patch statusbar missing" ]; check "status says missing" $?

# An OS update changed the file after patching: unapply removes just our lines.
fresh AppLayer-4.6.qml
run apply statusbar > /dev/null
sed -i 's/objectName: "appLayer"/objectName: "appLayer" \/\/ updated/' "$T"
run unapply statusbar > /dev/null
! grep -q VEETPATCHED "$T" && ! grep -q NotchStatusBar "$T" && grep -q '// updated' "$T"; check "after an update, unapply keeps the update and drops our lines" $?

# The app's requests, through "serve".
fresh AppLayer-5.2.qml
echo "apply statusbar 42" > "$W/out/request"
run serve
[ ! -e "$W/out/request" ]; check "serve: the request is taken" $?
grep -qx "request 42" "$W/out/status" && grep -qx "result statusbar applied" "$W/out/status" && grep -qx "patch statusbar applied" "$W/out/status"
check "serve: the answer names the request and the result" $?
grep -q "statusbar: applied" "$W/out/log"; check "serve: the log is handed over" $?
echo "unapply statusbar 43" > "$W/out/request"; run serve
grep -qx "result statusbar not-applied" "$W/out/status" && cmp -s "$T" "$W/original"; check "serve: unapply" $?
cp "$T" "$W/before"
for bad in "apply ../../etc 5" "apply statusbar;reboot 6" "rm -rf / 7" "apply STATUSBAR 8" "apply 9" ""; do
    printf '%s\n' "$bad" > "$W/out/request"; run serve
    grep -q "^result .*failed" "$W/out/status" && cmp -s "$T" "$W/before"
    check "serve refuses '$bad'" $?
done
ln -s "$T" "$W/out/request"; run serve 2> /dev/null
[ ! -e "$W/out/request" ] && cmp -s "$T" "$W/before"; check "serve refuses a request that's a symlink" $?
echo "status - 11" > "$W/out/request"; run serve
grep -qx "request 11" "$W/out/status" && grep -qx "patch statusbar not-applied" "$W/out/status"; check "serve: status" $?
run serve; check "serve with no request does nothing" $?

# unapply-all, for uninstalling and recovery.
fresh AppLayer-4.6.qml
run apply statusbar > /dev/null; run unapply-all > /dev/null
cmp -s "$T" "$W/original"; check "unapply-all puts the original back" $?
run apply nonsense 2> /dev/null; [ $? = 2 ]; check "the command line refuses unknown patches" $?

# --- Logging ---
L="$W/state/log"
fresh AppLayer-5.2.qml
mkdir -p "$W/root/etc"; printf 'NAME="Sailfish OS"\nVERSION_ID=5.2.0.15\n' > "$W/root/etc/os-release"
echo "apply statusbar 50" > "$W/out/request"; run serve
grep -q "INFO  request #50: apply statusbar" "$L"; check "log: the request" $?
grep -q "INFO  context: Sailfish OS 5.2.0.15, .*helper 0.2.0" "$L"; check "log: the phone's context" $?
grep -q "INFO  statusbar: applying to /usr/share/lipstick-jolla-home-qt5/layers/AppLayer.qml" "$L"; check "log: what it changes" $?
grep -Eq "INFO  statusbar: /usr/share/.*AppLayer.qml is [0-9]+ lines, [0-9]+ bytes, sha256 [0-9a-f]{12}" "$L"; check "log: the file before, with its checksum" $?
grep -q "INFO  statusbar: backed up to" "$L" && grep -Eq "INFO  statusbar: block goes in before line [0-9]+" "$L"; check "log: the backup and where the block goes" $?
grep -q "INFO  statusbar: checked: taking it out again gives the original" "$L"; check "log: the check" $?
grep -Eq "INFO  statusbar: applied; .* is now [0-9]+ lines" "$L"; check "log: the result, with the file after" $?
grep -q "INFO  request #50 answered: statusbar applied" "$L"; check "log: the answer" $?
grep -q "request #50: apply statusbar" "$W/out/log"; check "log: handed to the app" $?
echo "unapply statusbar 51" > "$W/out/request"; run serve
grep -q "INFO  statusbar: putting the original back from the backup" "$L" && grep -q "INFO  statusbar: removed;" "$L"; check "log: taking it out" $?
printf 'rm -rf /secret-stuff 52\n' > "$W/out/request"; run serve
grep -q "WARN  refused an unknown request (" "$L" && ! grep -q "secret-stuff" "$L"; check "log: a refused request, without its contents" $?
echo "apply ../../etc/passwd 53" > "$W/out/request"; run serve
grep -q "INFO  request #53: apply -" "$L" && grep -q "WARN  request #53 refused: there's no such patch" "$L" && ! grep -q "passwd" "$L"
check "log: an unknown patch, without its name" $?
sed -i 's/id: appLayer/id: other/' "$T"; run apply statusbar > /dev/null
grep -q "ERROR statusbar: not applied: .* has no 'id: appLayer'" "$L"; check "log: a wrong file is an ERROR, saying why" $?
fresh AppLayer-4.6.qml
run apply statusbar > /dev/null; sed -i 's/objectName: "appLayer"/objectName: "appLayer" \/\/ updated/' "$T"; run unapply statusbar > /dev/null
grep -q "WARN  statusbar: .* changed since it was patched (an update?)" "$W/state/log"; check "log: an updated file is a WARN" $?
bad=$(grep -Evc '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} (INFO |WARN |ERROR) ' "$W/state/log")
[ "$bad" = 0 ]; check "log: every line has a time and a level" $?
# Rotation: past 256 kB, the log moves to log.1 and starts again.
fresh AppLayer-4.6.qml
mkdir -p "$W/state"; awk 'BEGIN { for (i = 0; i < 4000; i++) print "2026-01-01 00:00:00 INFO  filler line number " i " to make the log big" }' > "$W/state/log"
run apply statusbar > /dev/null
[ -f "$W/state/log.1" ] && [ "$(wc -c < "$W/state/log")" -lt 20000 ] && grep -q "statusbar: applied" "$W/state/log"
check "log: rotated past 256 kB, the new entries kept" $?

echo; echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]

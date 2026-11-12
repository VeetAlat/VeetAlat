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
export VP_ROOT="$W/root" VP_PATCHES="$HERE/patches" VP_STATE="$W/state" VP_OUT="$W/out" VP_USER="$(id -un)"
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

echo; echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]

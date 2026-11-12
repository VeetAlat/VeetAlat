#!/bin/sh
#
# Checks the patch the way Patchmanager uses it, on copies of the home
# screen's AppLayer.qml from Sailfish OS 4.6 and from the phone (5.2):
# "already applied?" (a reverse dry run must fail), a dry run, applying,
# and taking it off again. Exact matches only (no fuzz). Also checks the
# bar's files are the same as VeetPatched's, where they're tested, and
# that the package installs them all. Run: sh tests/test_patch.sh

HERE=$(cd "$(dirname "$0")/.." && pwd)
FIX="$HERE/../sailfish-veetpatched/tests/fixtures"
PATCH="$HERE/patch/unified_diff.patch"
F=usr/share/lipstick-jolla-home-qt5/layers/AppLayer.qml
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
check() {
    if [ "$2" = 0 ]; then echo "ok   - $1"; PASS=$((PASS + 1)); else echo "FAIL - $1"; FAIL=$((FAIL + 1)); fi
}
pm() { patch -p1 --fuzz=0 -d "$W/root" "$@" < "$PATCH" > "$W/patch.out" 2>&1; }

for v in 4.6 5.2; do
    rm -rf "$W/root"; mkdir -p "$W/root/$(dirname $F)"
    cp "$FIX/AppLayer-$v.qml" "$W/root/$F"
    ! pm -R --dry-run; check "$v: not taken as already applied" $?
    pm --dry-run; check "$v: the dry run passes" $?
    pm; check "$v: it applies" $?
    [ "$(grep -c 'source: "file:///usr/share/sailfishos-patch-statusbar/NotchStatusBar.qml"' "$W/root/$F")" = 1 ]
    check "$v: the Loader for the bar is in, once" $?
    [ "$(tail -n 1 "$W/root/$F")" = "}" ] && grep -B1 -A11 '^    // StatusBar patch' "$W/root/$F" | head -n 1 | grep -qx ""
    check "$v: inside the app layer, at its end" $?
    ! ls "$W/root/$(dirname $F)" | grep -q -E '\.rej$'; check "$v: nothing rejected" $?
    if [ "$v" = 5.2 ]; then
        # The phone's file: exactly where the diff says (4.6's is two lines
        # shorter, so there it goes in two lines earlier, which is fine).
        ! grep -q -i -E "offset|fuzz" "$W/patch.out"; check "$v: right where the diff says, no offset" $?
    fi
    pm -R --dry-run; check "$v: Patchmanager sees it as applied" $?
    pm -R; cmp -s "$FIX/AppLayer-$v.qml" "$W/root/$F"; check "$v: taking it off gives the original, byte for byte" $?
done

for f in NotchStatusBar CompactBattery BatteryFromMce BatteryFromIndicator BatteryFromSettings; do
    cmp -s "$HERE/qml/$f.qml" "$HERE/../sailfish-veetpatched/patches/statusbar/$f.qml"
    check "$f.qml is VeetPatched's, as tested there" $?
    grep -q "qml/$f.qml\|qml/\*.qml" "$HERE/rpm/sailfishos-patch-statusbar.spec"; check "$f.qml is installed" $?
done
python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); sys.exit(0 if all(k in d for k in ("display_name", "description", "category", "infos")) and d["infos"].get("version") else 1)' \
    "$HERE/patch/patch.json"
check "patch.json is valid, with what Patchmanager shows" $?
v_json=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["infos"]["version"])' "$HERE/patch/patch.json")
v_spec=$(sed -n 's/^Version: *//p' "$HERE/rpm/sailfishos-patch-statusbar.spec")
[ "$v_json" = "$v_spec" ]; check "patch.json and the package have the same version ($v_spec)" $?

echo; echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]

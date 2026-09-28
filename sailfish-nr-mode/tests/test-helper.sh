#!/bin/sh
#
# Runs nr-mode-helper against a fake ofono on a private D-Bus, inside a
# scratch root, with systemctl stubbed out. Needs dbus-daemon and a python3
# with dbus-python and PyGObject (set PYTHON to pick one).

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
HELPER=$HERE/../helper/nr-mode-helper
PYTHON=${PYTHON:-python3}

WORK=$(mktemp -d)
BUS_PID=
OFONO_PID=
# shellcheck disable=SC2317  # only called via trap
cleanup() {
    [ -n "$OFONO_PID" ] && kill "$OFONO_PID" 2>/dev/null
    [ -n "$BUS_PID" ] && kill "$BUS_PID" 2>/dev/null
    rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p "$WORK/root/etc/ofono" "$WORK/bin"
cat > "$WORK/root/etc/ofono/binder.conf" <<EOF
[Settings]
ExpectSlots=slot1,slot2

[slot1]
path=slot1

[slot2]
path=slot2
lteNetworkMode=9
EOF

# systemctl stub: record restarts instead of touching the real system.
cat > "$WORK/bin/systemctl" <<EOF
#!/bin/sh
echo "\$*" >> "$WORK/systemctl.log"
EOF
chmod +x "$WORK/bin/systemctl"

cat > "$WORK/bus.conf" <<EOF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>custom</type>
  <listen>unix:path=$WORK/bus</listen>
  <policy context="default">
    <allow user="*"/>
    <allow own="*"/>
    <allow send_destination="*"/>
    <allow receive_sender="*"/>
  </policy>
</busconfig>
EOF
dbus-daemon --config-file="$WORK/bus.conf" --nofork 2> /dev/null &
BUS_PID=$!

export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$WORK/bus"
export FAKE_OFONO_LOG="$WORK/ofono.log"
export FAKE_OFONO_STATUS_FILE="$WORK/status"
export NR_MODE_ROOT="$WORK/root"
export PATH="$WORK/bin:$PATH"

i=0
until [ -S "$WORK/bus" ] || [ $i -gt 50 ]; do sleep 0.1; i=$((i + 1)); done
"$PYTHON" "$HERE/fake_ofono.py" &
OFONO_PID=$!
i=0
until dbus-send --system --print-reply --dest=org.ofono / \
        org.ofono.Manager.GetModems > /dev/null 2>&1; do
    i=$((i + 1))
    [ $i -gt 50 ] && { echo "fake ofono did not start"; exit 1; }
    sleep 0.1
done

FAILED=0
check() {
    if eval "$2"; then
        echo "ok   - $1"
    else
        echo "FAIL - $1"
        FAILED=1
    fi
}

DROPIN=$NR_MODE_ROOT/etc/ofono/binder.d/90-nr-mode.conf
STATE=$NR_MODE_ROOT/run/nr-mode/state

echo "--- on-keep"
"$HELPER" on-keep
check "drop-in written" "[ -f '$DROPIN' ]"
check "[Settings] gets NR_ONLY (23)" \
    "grep -A1 '^\[Settings\]' '$DROPIN' | grep -qx 'lteNetworkMode=23'"
check "existing slot1 overridden" \
    "grep -A1 '^\[slot1\]' '$DROPIN' | grep -qx 'lteNetworkMode=23'"
check "existing slot2 overridden" \
    "grep -A1 '^\[slot2\]' '$DROPIN' | grep -qx 'lteNetworkMode=23'"
check "ofono restarted" "grep -qx 'restart ofono.service' '$WORK/systemctl.log'"
check "preference set to lte" "tail -n1 '$FAKE_OFONO_LOG' | grep -qx 'TechnologyPreference=lte'"
check "previous preference saved" \
    "grep -qx '/ril_0 nr' '$NR_MODE_ROOT/var/lib/nr-mode/saved-preferences'"
check "state is on" "grep -qx on '$STATE'"
check "status reports on" "[ \"\$('$HELPER' status)\" = on ]"

echo "--- off"
"$HELPER" off
check "drop-in removed" "[ ! -f '$DROPIN' ]"
check "preference restored to nr" "tail -n1 '$FAKE_OFONO_LOG' | grep -qx 'TechnologyPreference=nr'"
check "state is off" "grep -qx off '$STATE'"

echo "--- apply via request file"
printf 'on\n' > "$NR_MODE_ROOT/run/nr-mode/request"
"$HELPER" apply
check "request 'on' with coverage stays on" "grep -qx on '$STATE'"
"$HELPER" off > /dev/null 2>&1

echo "--- auto revert without coverage"
echo searching > "$FAKE_OFONO_STATUS_FILE"
NR_MODE_REVERT_TIMEOUT=2 "$HELPER" on 2> /dev/null || true
check "reverted when nothing registers" "grep -q '^reverted' '$STATE'"
check "drop-in gone after revert" "[ ! -f '$DROPIN' ]"
check "preference back to nr after revert" \
    "tail -n1 '$FAKE_OFONO_LOG' | grep -qx 'TechnologyPreference=nr'"

echo "--- junk request"
printf 'rm -rf /\n' > "$NR_MODE_ROOT/run/nr-mode/request"
if "$HELPER" apply 2> /dev/null; then rc=0; else rc=$?; fi
check "junk request rejected" "[ $rc -ne 0 ] && grep -q '^error' '$STATE'"
check "junk request touched nothing" "[ ! -f '$DROPIN' ]"

exit $FAILED

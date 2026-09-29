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
export FAKE_OFONO_TECHS_FILE="$WORK/techs"
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

echo "--- revert timeout"
printf 'on-180\n' > "$NR_MODE_ROOT/run/nr-mode/request"
echo registered > "$FAKE_OFONO_STATUS_FILE"
"$HELPER" apply 2> /dev/null
check "request on-180 uses a 180s window" "grep -q 'auto-revert: 180s' '$NR_MODE_ROOT/run/nr-mode/log'"
"$HELPER" off > /dev/null 2>&1
if "$HELPER" on 12x > /dev/null 2>&1; then rc=0; else rc=$?; fi
check "on rejects a non-numeric timeout" "[ $rc -eq 2 ] && [ ! -f '$DROPIN' ]"
printf 'on-9999\n' > "$NR_MODE_ROOT/run/nr-mode/request"
if "$HELPER" apply 2> /dev/null; then rc=0; else rc=$?; fi
check "apply rejects an unlisted timeout" "[ $rc -ne 0 ] && [ ! -f '$DROPIN' ]"
echo searching > "$FAKE_OFONO_STATUS_FILE"

echo "--- logging"
LOG=$NR_MODE_ROOT/run/nr-mode/log
check "log file written" "[ -s '$LOG' ]"
check "log lines are timestamped" "head -n1 '$LOG' | grep -Eq '^[0-9]{2}:[0-9]{2}:[0-9]{2} '"
check "log records the preference change" "grep -q 'TechnologyPreference -> lte (ok' '$LOG'"
check "log records registration state" "grep -q 'registration=registered tech=nr strength=62%' '$LOG'"
check "log records the serving cell" "grep -q 'serving cell: nr .*ssRsrp=-95dBm' '$LOG'"
check "log counts visible cells" "grep -q 'cells visible: 2 (nr: 1, lte: 1, 3G: 0, 2G: 0)' '$LOG'"
check "log records the revert" "grep -q 'no registration within 2s' '$LOG'"

echo "--- diag"
DIAG=$("$HELPER" diag 2>&1)
# shellcheck disable=SC2317  # used inside check's eval
has() { printf '%s\n' "$DIAG" | grep -q -- "$1"; }
check "diag shows SIM provider" "has 'ServiceProviderName: Fake Telecom'"
check "diag masks the IMSI" "has 'SubscriberIdentity: 24491…90' && ! has '244911234567890'"
check "diag masks the ICCID" "! has '8935891000012345678'"
check "diag shows booleans without type word" "has 'Present: true'"
check "diag formats nested dicts" \
    "has 'ServiceNumbers: Customer care = +35840999; Voicemail = +358401234' || has 'ServiceNumbers: Voicemail = +358401234; Customer care = +35840999'"
check "diag shows the APN" "has 'AccessPointName: internet'"
check "diag hides APN password" "has 'Password: \*\*\*' && ! has secret"
check "diag shows the context header" "has '\[/ril_0/context1\]'"
check "diag shows available technologies" "has 'AvailableTechnologies: gsm umts lte nr'"
check "diag converts NR signal" "has 'nr SERVING .*ssRsrp=-95dBm ssRsrq=-11dB ssSinr=14dB'"
check "diag converts LTE signal" "has 'lte neighbour .*rsrp=-101dBm rsrq=-9dB rssnr=12.5dB'"
check "diag includes binder config" "has 'ExpectSlots=slot1,slot2'"

printf 'diag\n' > "$NR_MODE_ROOT/run/nr-mode/request"
"$HELPER" apply 2> /dev/null
check "diag request writes diag.txt" "grep -q 'Cells the modem can see' '$NR_MODE_ROOT/run/nr-mode/diag.txt'"

echo "--- watch"
echo registered > "$FAKE_OFONO_STATUS_FILE"
watch_ok=no
timeout 3 "$HELPER" watch 1 2>&1 |
    grep -q '/ril_0 registered .*nr .*62% Fake Telecom' && watch_ok=yes
check "watch prints live state" "[ $watch_ok = yes ]"

echo "--- ofono config without nr"
echo "gsm umts lte" > "$FAKE_OFONO_TECHS_FILE"
"$HELPER" off > /dev/null 2>&1
dbus-send --system --print-reply --dest=org.ofono /ril_0 org.ofono.RadioSettings.SetProperty \
    string:TechnologyPreference variant:string:lte > /dev/null
printf '[Settings]\ntechnologies=gsm,umts,lte\n' > "$NR_MODE_ROOT/etc/ofono/binder.d/10-vendor.conf"
"$HELPER" on-keep 2> /dev/null
check "switches on although ofono hides nr" "grep -qx on '$STATE' && [ -f '$DROPIN' ]"
check "explains why nr is missing" "grep -q 'sets technologies=gsm,umts,lte' '$LOG'"
check "still asks ofono for lte" "tail -n1 '$FAKE_OFONO_LOG' | grep -qx 'TechnologyPreference=lte'"
"$HELPER" off 2> /dev/null
check "off restores lte, not an unavailable nr" \
    "tail -n1 '$FAKE_OFONO_LOG' | grep -qx 'TechnologyPreference=lte' && grep -qx off '$STATE'"
rm -f "$NR_MODE_ROOT/etc/ofono/binder.d/10-vendor.conf" "$FAKE_OFONO_TECHS_FILE"
"$HELPER" off > /dev/null 2>&1

echo "--- ril plugin"
mv "$NR_MODE_ROOT/etc/ofono/binder.conf" "$WORK/binder.conf.saved"
printf '[Settings]\n\n[ril_0]\nsocket=/dev/socket/rild\n\n[ril_1]\nsocket=/dev/socket/rild2\nlteNetworkMode=9\n' \
    > "$NR_MODE_ROOT/etc/ofono/ril_subscription.conf"
RIL_DROPIN=$NR_MODE_ROOT/etc/ofono/ril_subscription.d/90-nr-mode.conf
"$HELPER" on-keep 2> /dev/null
check "ril: drop-in in ril_subscription.d" "[ -f '$RIL_DROPIN' ] && [ ! -f '$DROPIN' ]"
check "ril: [Settings] gets 23" "grep -A1 '^\[Settings\]' '$RIL_DROPIN' | grep -qx 'lteNetworkMode=23'"
check "ril: existing [ril_1] overridden" "grep -A1 '^\[ril_1\]' '$RIL_DROPIN' | grep -qx 'lteNetworkMode=23'"
check "ril: status reports on" "[ \"\$('$HELPER' status)\" = on ]"
check "ril: log names the plugin" "grep -q 'ofono plugin: ril' '$LOG'"
"$HELPER" off 2> /dev/null
check "ril: off removes drop-in" "[ ! -f '$RIL_DROPIN' ] && grep -qx off '$STATE'"
rm -f "$NR_MODE_ROOT/etc/ofono/ril_subscription.conf"
mv "$WORK/binder.conf.saved" "$NR_MODE_ROOT/etc/ofono/binder.conf"

echo "--- junk request"
printf 'rm -rf /\n' > "$NR_MODE_ROOT/run/nr-mode/request"
if "$HELPER" apply 2> /dev/null; then rc=0; else rc=$?; fi
check "junk request rejected" "[ $rc -ne 0 ] && grep -q '^error' '$STATE'"
check "junk request touched nothing" "[ ! -f '$DROPIN' ]"

exit $FAILED

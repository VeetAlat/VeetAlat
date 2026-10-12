#!/bin/bash
# Exercises the backend end to end with tests/fake-crosvm (or a real crosvm via CROSVM=...).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$HERE")
export SAILVISOR_DATA=$(mktemp -d)
export SAILVISOR_CROSVM=${CROSVM:-$HERE/fake-crosvm}
export SAILVISOR_GZVM=${GZVM:-/dev/null}
export SAILVISOR_SHARE=${SHARE:-$SAILVISOR_DATA/share}
export SAILVISOR_PYTHON=$ROOT/src/python
CLI="python3 $ROOT/src/sailvisor-cli"
mkdir -p "$SAILVISOR_SHARE/guest"
[ -f "$SAILVISOR_SHARE/guest/Image" ] || { echo dummy > "$SAILVISOR_SHARE/guest/Image"; echo dummy > "$SAILVISOR_SHARE/guest/initrd.img"; }

fails=0
check() {  # check <description> <command...>
    local d=$1; shift
    if "$@" >/tmp/sv-check.out 2>&1; then echo "PASS  $d"; else echo "FAIL  $d"; sed 's/^/      /' /tmp/sv-check.out; fails=$((fails+1)); fi
}
state() { $CLI status "$1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["state"])'; }

check "doctor runs" bash -c "$CLI doctor; true"
check "selftest passes" $CLI selftest --timeout 20
ID=$($CLI create-test --name "Heart beat")
check "create-test -> $ID" test "$ID" = heart-beat
check "start" $CLI start "$ID"
sleep 2
check "state running" test "$(state $ID)" = running
check "console has heartbeat" bash -c "$CLI console $ID | grep -q heartbeat"
check "guest_ready recorded" bash -c "$CLI status $ID | grep -q '\"guest_ready\": true'"
check "send to console" $CLI send "$ID" hello world
sleep 1
check "console echo" bash -c "$CLI console $ID | grep -q 'guest got: hello world'"
check "double start refused" bash -c "! $CLI start $ID"
check "stop" $CLI stop "$ID"
check "state stopped" test "$(state $ID)" = stopped
check "exit reason recorded" bash -c "$CLI status $ID | grep -q '\"exit_code\": 0'"
check "vm.log has events" bash -c "$CLI log $ID | grep -q 'crosvm exited'"

$CLI set "$ID" "cmdline=panic=-1 ignore-stop" >/dev/null
check "start (ignores stop)" $CLI start "$ID"
sleep 1.5
check "stop escalates to SIGTERM" $CLI stop "$ID" --timeout 25
check "escalation logged" bash -c "$CLI log $ID | grep -E 'sending SIG(TERM|KILL)|crosvm exited' | tail -3; $CLI log $ID | grep -q 'sending SIGKILL'"

check "start again" $CLI start "$ID"
sleep 1
check "kill" $CLI kill "$ID"
check "state after kill" bash -c "$CLI status $ID | grep -q SIGKILL"
check "previous logs rotated" test -f "$SAILVISOR_DATA/vms/$ID/vm.log.1"

FID=$($CLI create-test --name failer)
$CLI set "$FID" "cmdline=fail-early" >/dev/null
check "start failing VM" $CLI start "$FID"
sleep 1.5
check "early failure -> failed" test "$(state $FID)" = failed
check "error captured" bash -c "$CLI status $FID | grep -q 'failed to open GenieZone'"

# supervisor killed hard -> stale detection
check "start for stale test" $CLI start "$ID"
sleep 1
SUP=$($CLI status "$ID" | python3 -c 'import json,sys; print(json.load(sys.stdin)["supervisor_pid"])')
CVM=$($CLI status "$ID" | python3 -c 'import json,sys; print(json.load(sys.stdin)["crosvm_pid"])')
kill -9 "$SUP" "$CVM"; sleep 0.5
check "stale state detected as dead" test "$(state $ID)" = dead
check "kill clears stale state" $CLI kill "$ID"
check "state stopped after clear" test "$(state $ID)" = stopped

check "report written" bash -c "test -s \$($CLI report)"
check "delete" $CLI delete "$FID"
check "bridge API" python3 -c "
import sys; sys.path.insert(0, '$ROOT/src/python')
from sailvisor import bridge as b
assert b.info()['ok']; r = b.list_vms(); assert r['ok'] and len(r['result']) == 2, r
assert not b.start_vm('nope')['ok']; assert b.run_doctor()['ok']
g = b.get_vm('$ID'); assert g['ok'] and g['result']['command'][0].endswith('crosvm'), g
"
echo
[ $fails -eq 0 ] && echo "ALL TESTS PASSED" || echo "$fails TEST(S) FAILED"
rm -rf "$SAILVISOR_DATA"
exit $fails

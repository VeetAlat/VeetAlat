"""sailvisor-cli: everything the app can do, from the terminal, with verbose output for debugging."""

import argparse
import json
import os
import shlex
import sys
import time

from . import VERSION, control, doctor, iso, log, paths, report, vm

COLORS = {"ok": "\033[32m", "warn": "\033[33m", "fail": "\033[31m", "info": "\033[36m"}
RESET = "\033[0m"


def color(status, text):
    return COLORS.get(status, "") + text + RESET if sys.stdout.isatty() else text


def cmd_doctor(a):
    checks = doctor.run_checks()
    for c in checks:
        print("%s %s" % (color(c["status"], "[%-4s]" % c["status"].upper()), c["title"]))
        for line in str(c["detail"]).splitlines():
            print("       %s" % line)
    o = doctor.overall(checks)
    print("\noverall: %s" % color(o, o.upper()))
    return 0 if o != "fail" else 1


def cmd_list(a):
    ids = vm.list_ids()
    if not ids:
        print("no VMs yet - try: sailvisor-cli create-test")
        return 0
    print("%-24s %-10s %4s %7s  %s" % ("ID", "STATE", "CPUS", "MEM", "NAME"))
    for i in ids:
        s = vm.summary(i)
        print("%-24s %-10s %4d %6dM  %s" % (i, s["state"], s["cpus"], s["memory_mb"], s["name"]))
    return 0


def cmd_show(a):
    cfg = vm.load(a.vm)
    print(json.dumps({"config": cfg, "status": vm.status(a.vm), "problems": control.preflight(cfg)},
                     indent=2, sort_keys=True))
    print("\ncrosvm command:")
    print(" ".join(shlex.quote(c) for c in vm.crosvm_command(cfg, "<console.sock>", "<ctl.sock>")))
    return 0


def cmd_create(a):
    fields = {"name": a.name, "cpus": a.cpus, "memory_mb": a.memory, "kernel": os.path.abspath(a.kernel),
              "initrd": os.path.abspath(a.initrd) if a.initrd else "", "cmdline": a.cmdline,
              "log_level": a.log_level, "iso": os.path.abspath(a.iso) if a.iso else "",
              "disks": [{"path": os.path.abspath(d), "ro": False} for d in a.disk],
              "extra_args": a.extra or []}
    vm_id = vm.create(fields)
    print(vm_id)
    return 0


def cmd_create_test(a):
    vm_id = vm.create({"name": a.name, "kernel": paths.TEST_KERNEL, "initrd": paths.TEST_INITRD,
                       "memory_mb": 256, "log_level": a.log_level,
                       "cmdline": "panic=-1 sailvisor.mode=%s" % a.mode})
    print(vm_id)
    return 0


def cmd_import_iso(a):
    vm_id, info = iso.import_iso(a.iso, a.name, a.memory)
    print("detected %(profile)s ISO '%(label)s': kernel=%(kernel)s initrd=%(initrd)s" % info)
    print("cmdline: %s" % info["cmdline"])
    print(vm_id)
    return 0


def cmd_set(a):
    fields = {}
    for kv in a.settings:
        k, _, v = kv.partition("=")
        if k not in vm.DEFAULTS:
            print("unknown setting %s (valid: %s)" % (k, ", ".join(sorted(vm.DEFAULTS))), file=sys.stderr)
            return 2
        if isinstance(vm.DEFAULTS[k], int):
            v = int(v)
        elif isinstance(vm.DEFAULTS[k], list):
            v = json.loads(v) if v.startswith("[") else shlex.split(v)
        fields[k] = v
    vm.update(a.vm, fields)
    return cmd_show(a)


def cmd_start(a):
    st = control.start(a.vm)
    print("started %s (supervisor %s, crosvm %s)" % (a.vm, st.get("supervisor_pid"), st.get("crosvm_pid")))
    if a.follow:
        return follow_console(a.vm)
    return 0


def cmd_stop(a):
    control.stop(a.vm)
    st = control.wait_stopped(a.vm, a.timeout)
    print("%s: %s %s" % (a.vm, st["state"], st.get("exit_reason", "")))
    return 0 if st["state"] not in vm.ACTIVE_STATES else 1


def cmd_kill(a):
    st = control.kill(a.vm)
    print("%s: %s %s" % (a.vm, st["state"], st.get("exit_reason", "")))
    return 0


def cmd_status(a):
    print(json.dumps(vm.status(a.vm), indent=2, sort_keys=True))
    return 0


def follow_file(path, stop_when=None):
    pos = 0
    try:
        while True:
            try:
                with open(path, "rb") as f:
                    f.seek(pos)
                    data = f.read()
                    pos = f.tell()
                if data:
                    sys.stdout.write(data.decode("utf-8", "replace"))
                    sys.stdout.flush()
            except FileNotFoundError:
                pass
            if stop_when and stop_when():
                break
            time.sleep(0.3)
    except KeyboardInterrupt:
        print()
    return 0


def follow_console(vm_id):
    print("--- console of %s (Ctrl+C to detach, VM keeps running) ---" % vm_id)
    return follow_file(vm.file_path(vm_id, "console.log"),
                       lambda: vm.status(vm_id)["state"] not in vm.ACTIVE_STATES)


def cmd_console(a):
    if a.follow:
        return follow_console(a.vm)
    sys.stdout.write(control.tail_file(vm.file_path(a.vm, "console.log"), a.bytes))
    return 0


def cmd_log(a):
    path = log.app_log_path() if a.vm == "app" else vm.file_path(a.vm, a.file)
    if a.follow:
        return follow_file(path)
    sys.stdout.write(control.tail_file(path, a.bytes))
    return 0


def cmd_send(a):
    control.send_console(a.vm, " ".join(a.text) + "\n")
    return 0


def cmd_run(a):
    cmd = control.foreground_command(a.vm)
    problems = control.preflight(vm.load(a.vm))
    if problems:
        print("warning: %s" % "; ".join(problems), file=sys.stderr)
    print("exec: %s" % " ".join(shlex.quote(c) for c in cmd), file=sys.stderr)
    sys.stderr.flush()
    os.environ["RUST_BACKTRACE"] = "1"
    os.execv(cmd[0], cmd)


def cmd_delete(a):
    vm.delete(a.vm)
    print("deleted %s" % a.vm)
    return 0


def cmd_selftest(a):
    vm_id = control.ensure_selftest_vm()
    print("starting boot self-test (bundled guest, 1 vCPU, 256 MiB)...")
    try:
        control.start(vm_id)
    except vm.VmError as e:
        print(color("fail", "could not start: %s" % e))
        return 1
    follow_file(vm.file_path(vm_id, "console.log"),
                lambda: vm.status(vm_id)["state"] not in vm.ACTIVE_STATES) if a.verbose else None
    st = control.wait_stopped(vm_id, a.timeout)
    if st["state"] in vm.ACTIVE_STATES:
        print("timed out after %ds, stopping" % a.timeout)
        control.stop(vm_id)
        control.wait_stopped(vm_id, 20)
    res = control.selftest_result(vm_id)
    print()
    for c in res["checks"]:
        print("%s %s" % (color("ok" if c["ok"] else "fail", "[%s]" % ("PASS" if c["ok"] else "FAIL")), c["title"]))
    if res["timings"]:
        print("timings (s since start): %s" % ", ".join("%s=%s" % kv for kv in sorted(res["timings"].items())))
    print("exit: %s" % res["exit_reason"])
    for e in res["errors"]:
        print("error: %s" % e)
    if not res["passed"]:
        print("\n--- vm.log (tail) ---")
        print(control.tail_file(vm.file_path(vm_id, "vm.log"), 6000))
        print("--- console.log (tail) ---")
        print(control.tail_file(vm.file_path(vm_id, "console.log"), 3000))
        print("Full details: sailvisor-cli report")
    print("\nSELF-TEST %s" % color("ok" if res["passed"] else "fail", "PASSED" if res["passed"] else "FAILED"))
    return 0 if res["passed"] else 1


def cmd_report(a):
    path = report.save()
    print(path)
    return 0


def cmd_probe(a):
    print(json.dumps(doctor.gzvm_probe(), indent=2))
    return 0


def build_parser():
    p = argparse.ArgumentParser(prog="sailvisor-cli", description="Sailvisor %s - VMs on GenieZone" % VERSION)
    p.add_argument("-v", "--verbose", action="store_true", help="debug logging to stderr")
    sub = p.add_subparsers(dest="command")

    def add(name, fn, help_, *vm_arg):
        sp = sub.add_parser(name, help=help_)
        if vm_arg:
            sp.add_argument("vm", help="VM id (see list)")
        sp.set_defaults(fn=fn)
        return sp

    add("doctor", cmd_doctor, "check whether this device can run VMs")
    add("probe", cmd_probe, "low-level GenieZone ioctl probe")
    sp = add("selftest", cmd_selftest, "boot the bundled guest and verify it works end to end")
    sp.add_argument("--timeout", type=int, default=120)
    add("list", cmd_list, "list VMs")
    add("show", cmd_show, "show VM config, state and crosvm command", 1)

    sp = add("create", cmd_create, "create a VM from a kernel (+initrd)")
    sp.add_argument("name")
    sp.add_argument("--kernel", required=True)
    sp.add_argument("--initrd")
    sp.add_argument("--cmdline", default="panic=-1")
    sp.add_argument("--cpus", type=int, default=1)
    sp.add_argument("--memory", type=int, default=512, help="MiB")
    sp.add_argument("--disk", action="append", default=[], help="disk image (repeatable)")
    sp.add_argument("--iso", help="attach an ISO read-only")
    sp.add_argument("--log-level", default="info")
    sp.add_argument("--extra", nargs=argparse.REMAINDER, help="raw extra crosvm run arguments")

    sp = add("create-test", cmd_create_test, "create a VM from the bundled test guest")
    sp.add_argument("--name", default="Test guest")
    sp.add_argument("--mode", default="heartbeat", choices=["heartbeat", "shell", "poweroff"])
    sp.add_argument("--log-level", default="info")

    sp = add("import-iso", cmd_import_iso, "(experimental) create a VM from a Linux ISO")
    sp.add_argument("iso")
    sp.add_argument("--name")
    sp.add_argument("--memory", type=int, default=2048)

    sp = add("set", cmd_set, "change settings, e.g. memory_mb=1024 log_level=debug", 1)
    sp.add_argument("settings", nargs="+", metavar="key=value")

    sp = add("start", cmd_start, "start a VM in the background", 1)
    sp.add_argument("-f", "--follow", action="store_true", help="then follow the console")
    sp = add("stop", cmd_stop, "graceful stop (escalates to SIGTERM/SIGKILL)", 1)
    sp.add_argument("--timeout", type=int, default=25)
    add("kill", cmd_kill, "force-kill a VM", 1)
    add("status", cmd_status, "runtime state as JSON", 1)

    sp = add("console", cmd_console, "show guest console output", 1)
    sp.add_argument("-f", "--follow", action="store_true")
    sp.add_argument("--bytes", type=int, default=32768)
    sp = add("send", cmd_send, "type a line into the guest console", 1)
    sp.add_argument("text", nargs="+")
    sp = add("log", cmd_log, "show the VM log (crosvm + supervisor); use 'app' for the app log", 1)
    sp.add_argument("--file", default="vm.log", choices=["vm.log", "vm.log.1", "supervisor.err"])
    sp.add_argument("-f", "--follow", action="store_true")
    sp.add_argument("--bytes", type=int, default=65536)

    add("run", cmd_run, "run crosvm in the foreground with the console on this terminal", 1)
    add("delete", cmd_delete, "delete a VM and its files", 1)
    add("report", cmd_report, "write a debug report file")
    return p


def main(argv=None):
    p = build_parser()
    a = p.parse_args(argv)
    if not getattr(a, "fn", None):
        p.print_help()
        return 1
    log.setup(verbose=a.verbose, stderr=a.verbose)
    log.get("cli").debug("argv: %s", sys.argv)
    try:
        return a.fn(a) or 0
    except (vm.VmError, iso.IsoError) as e:
        print(color("fail", "error: %s" % e), file=sys.stderr)
        return 1

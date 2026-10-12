"""Starting, stopping and talking to VMs."""

import errno
import os
import shutil
import signal
import subprocess
import time

from . import log, paths, vm

L = log.get("control")

SELFTEST_ID = "selftest"


def python_executable():
    # inside the QML app sys.executable is the launcher, not python
    return shutil.which("python3") or "/usr/bin/python3"


def preflight(cfg):
    problems = vm.validate(cfg)
    if not os.access(paths.CROSVM, os.X_OK):
        problems.append("crosvm not found or not executable at %s" % paths.CROSVM)
    if not os.path.exists(paths.GZVM_DEVICE):
        problems.append("%s does not exist - is this a GenieZone device?" % paths.GZVM_DEVICE)
    elif not os.access(paths.GZVM_DEVICE, os.R_OK | os.W_OK):
        problems.append("no read/write access to %s" % paths.GZVM_DEVICE)
    return problems


def start(vm_id, wait=5.0):
    cfg = vm.load(vm_id)
    st = vm.status(vm_id)
    if st["state"] in vm.ACTIVE_STATES:
        raise vm.VmError("VM is already %s" % st["state"])
    problems = preflight(cfg)
    if problems:
        L.warning("refusing to start %s: %s", vm_id, problems)
        raise vm.VmError("; ".join(problems))

    err_path = vm.file_path(vm_id, "supervisor.err")
    env = dict(os.environ)
    env["PYTHONPATH"] = paths.PYTHON_DIR + (":" + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
    cmd = [python_executable(), "-m", "sailvisor.supervisor", "--fork", vm_id]
    L.info("starting %s: %s", vm_id, cmd)
    t0 = time.time()
    with open(err_path, "ab") as err:
        launcher = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=err, stderr=err,
                                    cwd=vm.vm_dir(vm_id), env=env, close_fds=True)
        launcher.wait(timeout=10)  # exits right after forking the supervisor

    # wait until the supervisor has recorded itself
    deadline = time.time() + wait
    while time.time() < deadline:
        st = vm.read_state(vm_id)
        if st.get("supervisor_pid") and st.get("started_at", 0) >= t0 - 0.5:
            return vm.status(vm_id)
        time.sleep(0.1)
    msg = "supervisor did not start within %.0fs" % wait
    try:
        with open(err_path, "rb") as f:
            f.seek(0, 2)
            f.seek(max(0, f.tell() - 2000))
            tail = f.read().decode("utf-8", "replace").strip()
        if tail:
            msg += ": " + tail.splitlines()[-1]
    except OSError:
        pass
    L.error("%s for %s", msg, vm_id)
    raise vm.VmError(msg)


def stop(vm_id):
    """Graceful stop. The supervisor escalates to SIGTERM/SIGKILL if crosvm does not exit."""
    st = vm.status(vm_id)
    if st["state"] not in vm.ACTIVE_STATES:
        return st
    sup = st.get("supervisor_pid")
    if vm.pid_alive(sup, "sailvisor"):
        L.info("stopping %s (SIGTERM to supervisor %s)", vm_id, sup)
        os.kill(int(sup), signal.SIGTERM)
    else:
        crosvm_pid = st.get("crosvm_pid")
        L.warning("supervisor of %s is gone, stopping crosvm %s directly", vm_id, crosvm_pid)
        ctl = vm.file_path(vm_id, "ctl.sock")
        if os.path.exists(ctl):
            subprocess.run([paths.CROSVM, "--no-syslog", "stop", ctl], timeout=8,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if vm.pid_alive(crosvm_pid, "crosvm"):
            os.kill(int(crosvm_pid), signal.SIGTERM)
    return vm.status(vm_id)


def kill(vm_id):
    """Immediate SIGKILL of crosvm; the supervisor records the exit."""
    st = vm.status(vm_id)
    crosvm_pid, sup_pid = st.get("crosvm_pid"), st.get("supervisor_pid")
    if vm.pid_alive(crosvm_pid, "crosvm"):
        L.warning("SIGKILL crosvm pid %s of %s", crosvm_pid, vm_id)
        os.kill(int(crosvm_pid), signal.SIGKILL)  # the supervisor records the exit
        return wait_stopped(vm_id, 3)
    if vm.pid_alive(sup_pid, "sailvisor"):
        L.warning("SIGKILL supervisor pid %s of %s", sup_pid, vm_id)
        os.kill(int(sup_pid), signal.SIGKILL)
    if st["state"] in vm.ACTIVE_STATES + ("dead",):
        vm.write_state(vm_id, state="stopped", ended_at=time.time(),
                       exit_reason="force-killed / stale state cleared")
    return vm.status(vm_id)


def wait_stopped(vm_id, timeout):
    deadline = time.time() + timeout
    while time.time() < deadline:
        st = vm.status(vm_id)
        if st["state"] not in vm.ACTIVE_STATES:
            return st
        time.sleep(0.25)
    return vm.status(vm_id)


def send_console(vm_id, text):
    fifo = vm.file_path(vm_id, "console.in")
    try:
        fd = os.open(fifo, os.O_WRONLY | os.O_NONBLOCK)
    except OSError as e:
        if e.errno in (errno.ENOENT, errno.ENXIO):
            raise vm.VmError("VM console is not available (is the VM running?)")
        raise
    try:
        os.write(fd, text.encode())
    finally:
        os.close(fd)
    L.debug("sent %d bytes to console of %s", len(text), vm_id)


def tail_file(path, max_bytes=32768):
    try:
        with open(path, "rb") as f:
            f.seek(0, 2)
            size = f.tell()
            f.seek(max(0, size - max_bytes))
            data = f.read()
    except OSError:
        return ""
    text = data.decode("utf-8", "replace")
    if size > max_bytes:
        text = text.split("\n", 1)[-1]
    return text.replace("\r\n", "\n").replace("\r", "\n")


def foreground_command(vm_id):
    """crosvm command with the console on this terminal, for `sailvisor-cli run`."""
    cfg = vm.load(vm_id)
    cmd = vm.crosvm_command(cfg, "UNUSED", vm.file_path(vm_id, "ctl.sock"))
    i = cmd.index("--serial")
    cmd[i + 1] = "type=stdout,console,earlycon,stdin"
    return cmd


def ensure_selftest_vm(mode="poweroff"):
    fields = {
        "name": "Self-test",
        "cpus": 1,
        "memory_mb": 256,
        "kernel": paths.TEST_KERNEL,
        "initrd": paths.TEST_INITRD,
        "cmdline": "panic=-1 sailvisor.mode=%s" % mode,
        "log_level": "debug",
        "notes": "Boots the bundled test guest, prints a banner and powers off.",
    }
    if os.path.exists(vm.file_path(SELFTEST_ID, "vm.json")):
        if vm.status(SELFTEST_ID)["state"] not in vm.ACTIVE_STATES:
            vm.update(SELFTEST_ID, fields)
    else:
        vm.create(fields, vm_id=SELFTEST_ID)
    return SELFTEST_ID


def selftest_result(vm_id=SELFTEST_ID):
    st = vm.status(vm_id)
    console = tail_file(vm.file_path(vm_id, "console.log"), 65536)
    checks = [
        ("supervisor started", bool(st.get("supervisor_pid"))),
        ("crosvm started", bool(st.get("crosvm_pid"))),
        ("serial console connected", bool(st.get("console_connected_at"))),
        ("guest printed output", bool(st.get("first_output_at"))),
        ("guest init reached (ready marker)", "SAILVISOR_GUEST_READY" in console),
        ("guest powered off", "SAILVISOR_GUEST_POWEROFF" in console),
        ("crosvm exited cleanly", st.get("exit_code") == 0),
    ]
    passed = all(ok for _, ok in checks)
    timings = {}
    if st.get("started_at"):
        for key in ("console_connected_at", "first_output_at", "ended_at"):
            if st.get(key):
                timings[key.replace("_at", "")] = round(st[key] - st["started_at"], 2)
    return {"state": st["state"], "passed": passed, "finished": st["state"] not in vm.ACTIVE_STATES,
            "checks": [{"title": t, "ok": ok} for t, ok in checks], "timings": timings,
            "exit_reason": st.get("exit_reason", ""), "errors": st.get("errors", [])}

"""Per-VM supervisor process.

Started detached by control.start() as `python3 -m sailvisor.supervisor --fork <vm-id>`. It
  * listens on console.sock; crosvm connects to it as the guest serial console
  * copies guest console output to console.log, and console.in (a FIFO) to the guest
  * runs crosvm with stdout/stderr appended to vm.log, plus its own timestamped events
  * records state transitions and the exit reason in state.json
  * on SIGTERM: `crosvm stop` via the control socket, then SIGTERM, then SIGKILL
"""

import os
import selectors
import shlex
import signal
import socket
import subprocess
import sys
import time
import traceback

from . import log, paths, vm

READY_MARKER = b"SAILVISOR_GUEST_READY"
STOP_GRACE = 10      # seconds after `crosvm stop` before SIGTERM
TERM_GRACE = 5       # seconds after SIGTERM before SIGKILL
NO_CONSOLE_WARN = 20

EXIT_REASONS = {
    0: "stopped",
    1: "crosvm error (see VM log)",
    32: "guest requested reset",
    33: "VM crashed",
    34: "guest kernel panic",
    35: "invalid crosvm arguments",
    36: "watchdog reset (vCPU stall)",
}


def rotate(path, keep=2):
    for i in range(keep, 0, -1):
        src = path if i == 1 else "%s.%d" % (path, i - 1)
        if os.path.exists(src):
            os.replace(src, "%s.%d" % (path, i))


def last_error_lines(path, n=3):
    try:
        with open(path, "rb") as f:
            f.seek(0, 2)
            f.seek(max(0, f.tell() - 16384))
            lines = f.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return []
    errs = [l for l in lines if " ERROR " in l or "error:" in l.lower() or "panicked" in l]
    return errs[-n:]


class Supervisor:
    def __init__(self, vm_id):
        self.vm_id = vm_id
        self.dir = vm.vm_dir(vm_id)
        self.cfg = vm.load(vm_id)
        self.L = log.get("supervisor.%s" % vm_id)
        self.console_sock = os.path.join(self.dir, "console.sock")
        self.control_sock = os.path.join(self.dir, "ctl.sock")
        self.fifo = os.path.join(self.dir, "console.in")
        self.stop_requested = False
        self.conn = None
        self.proc = None

    # -- helpers
    def event(self, msg):
        line = "[%s] [sailvisor] %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg)
        self.vmlog.write(line.encode())
        self.L.info(msg)

    def _on_signal(self, signum, _frame):
        self.stop_requested = True

    def _cleanup_files(self):
        for p in (self.console_sock, self.control_sock, self.fifo):
            try:
                os.unlink(p)
            except FileNotFoundError:
                pass

    # -- main
    def run(self):
        rotate(os.path.join(self.dir, "console.log"))
        rotate(os.path.join(self.dir, "vm.log"))
        self.vmlog = open(os.path.join(self.dir, "vm.log"), "ab", buffering=0)
        self.console = open(os.path.join(self.dir, "console.log"), "ab", buffering=0)
        for s in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
            signal.signal(s, self._on_signal)

        self._cleanup_files()
        listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        listener.bind(self.console_sock)
        listener.listen(1)
        listener.setblocking(False)
        os.mkfifo(self.fifo, 0o600)
        fifo_fd = os.open(self.fifo, os.O_RDWR | os.O_NONBLOCK)

        cmd = vm.crosvm_command(self.cfg, self.console_sock, self.control_sock)
        started = time.time()
        vm.write_state(self.vm_id, state="starting", supervisor_pid=os.getpid(), crosvm_pid=None,
                       started_at=started, ended_at=None, exit_code=None, exit_reason="",
                       guest_ready=False, first_output_at=None, console_connected_at=None,
                       errors=[], command=cmd, note="")
        self.event("config: %s" % {k: self.cfg[k] for k in sorted(self.cfg)})
        self.event("starting crosvm: %s" % " ".join(shlex.quote(c) for c in cmd))

        env = dict(os.environ, RUST_BACKTRACE="1")
        try:
            self.proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=self.vmlog,
                                         stderr=self.vmlog, env=env, cwd=self.dir)
        except OSError as e:
            self.event("failed to execute crosvm: %s" % e)
            vm.write_state(self.vm_id, state="failed", ended_at=time.time(), exit_code=None,
                           exit_reason="could not execute crosvm: %s" % e)
            self._cleanup_files()
            return 1
        vm.write_state(self.vm_id, crosvm_pid=self.proc.pid)
        self.event("crosvm pid %d" % self.proc.pid)

        sel = selectors.DefaultSelector()
        sel.register(listener, selectors.EVENT_READ, "accept")
        sel.register(fifo_fd, selectors.EVENT_READ, "fifo")
        tail = b""
        stopping_since = None
        term_sent = kill_sent = warned = False
        first_output = False

        while True:
            for key, _ in sel.select(timeout=0.5):
                kind = key.data
                if kind == "accept":
                    self.conn, _ = listener.accept()
                    self.conn.setblocking(False)
                    sel.register(self.conn, selectors.EVENT_READ, "console")
                    self.event("guest serial console connected (%.1fs after start)" % (time.time() - started))
                    vm.write_state(self.vm_id, state="stopping" if stopping_since else "running",
                                   console_connected_at=time.time())
                elif kind == "console":
                    try:
                        data = self.conn.recv(65536)
                    except BlockingIOError:
                        continue
                    except OSError as e:
                        data = b""
                        self.event("console read error: %s" % e)
                    if not data:
                        sel.unregister(self.conn)
                        self.conn.close()
                        self.conn = None
                        self.event("guest serial console closed")
                        continue
                    self.console.write(data)
                    if not first_output:
                        first_output = True
                        self.event("first guest console output (%.1fs after start)" % (time.time() - started))
                        vm.write_state(self.vm_id, first_output_at=time.time())
                    tail = (tail + data)[-256:]
                    if READY_MARKER in tail:
                        tail = b""
                        self.event("guest reported ready (%.1fs after start)" % (time.time() - started))
                        vm.write_state(self.vm_id, guest_ready=True)
                elif kind == "fifo":
                    try:
                        data = os.read(fifo_fd, 4096)
                    except BlockingIOError:
                        continue
                    if data and self.conn:
                        try:
                            self.conn.setblocking(True)
                            self.conn.sendall(data)
                        except OSError as e:
                            self.event("console write error: %s" % e)
                        finally:
                            if self.conn:
                                self.conn.setblocking(False)

            if self.proc.poll() is not None:
                break

            now = time.time()
            if not warned and self.conn is None and now - started > NO_CONSOLE_WARN:
                warned = True
                self.event("WARNING: crosvm is running but has not connected the serial console after %ds"
                           % NO_CONSOLE_WARN)
            if self.stop_requested and stopping_since is None:
                stopping_since = now
                vm.write_state(self.vm_id, state="stopping")
                self.event("stop requested, asking crosvm to stop via control socket")
                self._crosvm_stop()
            if stopping_since is not None:
                if not term_sent and now - stopping_since > STOP_GRACE:
                    term_sent = True
                    self.event("crosvm did not stop after %ds, sending SIGTERM" % STOP_GRACE)
                    self.proc.terminate()
                elif not kill_sent and now - stopping_since > STOP_GRACE + TERM_GRACE:
                    kill_sent = True
                    self.event("crosvm still alive, sending SIGKILL")
                    self.proc.kill()

        # drain whatever the guest printed last
        if self.conn:
            try:
                self.conn.setblocking(True)
                self.conn.settimeout(0.5)
                while True:
                    data = self.conn.recv(65536)
                    if not data:
                        break
                    self.console.write(data)
            except OSError:
                pass

        rc = self.proc.returncode
        runtime = time.time() - started
        if rc < 0:
            try:
                reason = "killed by %s" % signal.Signals(-rc).name
            except ValueError:
                reason = "killed by signal %d" % -rc
        else:
            reason = EXIT_REASONS.get(rc, "crosvm exited with code %d" % rc)
        if rc == 0 or (stopping_since and rc in (-signal.SIGTERM, -signal.SIGKILL)):
            state = "stopped"
        elif runtime < 5 and not first_output:
            state = "failed"
        else:
            state = "crashed"
        errors = last_error_lines(os.path.join(self.dir, "vm.log"))
        self.event("crosvm exited: code=%s reason=%r runtime=%.1fs state=%s" % (rc, reason, runtime, state))
        for e in errors:
            self.event("last error: %s" % e)
        vm.write_state(self.vm_id, state=state, ended_at=time.time(), exit_code=rc,
                       exit_reason=reason, runtime=round(runtime, 1), errors=errors)
        self._cleanup_files()
        return 0

    def _crosvm_stop(self):
        if not os.path.exists(self.control_sock):
            self.event("no control socket, sending SIGTERM to crosvm")
            self.proc.terminate()
            return
        try:
            out = subprocess.run([paths.CROSVM, "--no-syslog", "stop", self.control_sock],
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=8)
            self.event("crosvm stop -> rc=%d %s" % (out.returncode, out.stdout.decode("utf-8", "replace").strip()))
        except (OSError, subprocess.TimeoutExpired) as e:
            self.event("crosvm stop failed: %s" % e)


def main(argv):
    fork = "--fork" in argv
    args = [a for a in argv if a != "--fork"]
    if len(args) != 1:
        print("usage: python3 -m sailvisor.supervisor [--fork] <vm-id>", file=sys.stderr)
        return 2
    vm_id = args[0]
    if fork:
        # double fork: the launcher reaps the intermediate child so the supervisor never
        # becomes a zombie of the app process
        if os.fork() > 0:
            os._exit(0)
        os.setsid()
        if os.fork() > 0:
            os._exit(0)
    log.setup()
    sup = None
    try:
        sup = Supervisor(vm_id)
        return sup.run()
    except Exception:
        tb = traceback.format_exc()
        log.get("supervisor").error("supervisor for %s crashed:\n%s", vm_id, tb)
        try:
            if sup is not None and getattr(sup, "vmlog", None):
                sup.event("SUPERVISOR CRASHED:\n" + tb)
            if sup is not None and sup.proc and sup.proc.poll() is None:
                sup.proc.kill()
            vm.write_state(vm_id, state="failed", ended_at=time.time(),
                           exit_reason="supervisor crashed: %s" % tb.strip().splitlines()[-1])
        except Exception:
            pass
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

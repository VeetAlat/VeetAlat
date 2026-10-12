"""VM definitions: storage on disk, runtime state, and the crosvm command line."""

import json
import os
import re
import shutil
import time

from . import log, paths

L = log.get("vm")

DEFAULTS = {
    "name": "",
    "cpus": 1,               # GenieZone support in crosvm is single-core for now
    "memory_mb": 512,
    "kernel": "",
    "initrd": "",
    "cmdline": "panic=-1",
    "disks": [],             # [{"path": "...", "ro": false}]
    "iso": "",               # attached read-only as an extra block device
    "log_level": "info",     # crosvm --log-level: error, warn, info, debug, trace
    "extra_args": [],        # raw extra arguments for `crosvm run`, for experiments
    "notes": "",
}

ACTIVE_STATES = ("starting", "running", "stopping")
MAX_ID_LEN = 24  # unix socket paths are limited to 108 bytes


class VmError(Exception):
    pass


def slugify(name):
    s = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return (s or "vm")[:MAX_ID_LEN].strip("-") or "vm"


def vm_dir(vm_id):
    if not re.match(r"^[a-z0-9][a-z0-9-]*$", vm_id or ""):
        raise VmError("invalid VM id: %r" % vm_id)
    return os.path.join(paths.vms_dir(), vm_id)


def file_path(vm_id, name):
    return os.path.join(vm_dir(vm_id), name)


def _write_json(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
    os.replace(tmp, path)


def _read_json(path, default=None):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


# ---------------------------------------------------------------- config

def list_ids():
    d = paths.vms_dir()
    return sorted(n for n in os.listdir(d) if os.path.isfile(os.path.join(d, n, "vm.json")))


def load(vm_id):
    cfg = _read_json(file_path(vm_id, "vm.json"))
    if cfg is None:
        raise VmError("no such VM: %s" % vm_id)
    merged = dict(DEFAULTS)
    merged.update(cfg)
    merged["id"] = vm_id
    return merged


def validate(cfg):
    """Return a list of human readable problems; empty means the VM can start."""
    problems = []
    if not cfg.get("kernel"):
        problems.append("no kernel selected")
    elif not os.path.isfile(cfg["kernel"]):
        problems.append("kernel not found: %s" % cfg["kernel"])
    if cfg.get("initrd") and not os.path.isfile(cfg["initrd"]):
        problems.append("initrd not found: %s" % cfg["initrd"])
    for disk in cfg.get("disks", []):
        if not os.path.exists(disk.get("path", "")):
            problems.append("disk not found: %s" % disk.get("path"))
    if cfg.get("iso") and not os.path.isfile(cfg["iso"]):
        problems.append("ISO not found: %s" % cfg["iso"])
    if not 1 <= int(cfg.get("cpus", 1)) <= 8:
        problems.append("cpus must be 1-8")
    if not 64 <= int(cfg.get("memory_mb", 0)) <= 8192:
        problems.append("memory must be 64-8192 MiB")
    return problems


def create(fields, vm_id=None):
    cfg = dict(DEFAULTS)
    cfg.update({k: v for k, v in fields.items() if k in DEFAULTS})
    cfg["name"] = (cfg.get("name") or "").strip() or "VM"
    cfg["cpus"] = int(cfg["cpus"])
    cfg["memory_mb"] = int(cfg["memory_mb"])
    base = vm_id or slugify(cfg["name"])
    vm_id, n = base, 2
    while os.path.exists(os.path.join(paths.vms_dir(), vm_id)):
        suffix = "-%d" % n
        vm_id = base[:MAX_ID_LEN - len(suffix)] + suffix
        n += 1
    os.makedirs(vm_dir(vm_id))
    cfg["created"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    _write_json(file_path(vm_id, "vm.json"), cfg)
    L.info("created VM %s: %s", vm_id, json.dumps(cfg, sort_keys=True))
    return vm_id


def update(vm_id, fields):
    cfg = load(vm_id)
    if status(vm_id)["state"] in ACTIVE_STATES:
        raise VmError("stop the VM before editing it")
    for k, v in fields.items():
        if k in DEFAULTS:
            cfg[k] = v
    cfg["cpus"] = int(cfg["cpus"])
    cfg["memory_mb"] = int(cfg["memory_mb"])
    cfg.pop("id", None)
    _write_json(file_path(vm_id, "vm.json"), cfg)
    L.info("updated VM %s: %s", vm_id, json.dumps(fields, sort_keys=True))


def delete(vm_id):
    if status(vm_id)["state"] in ACTIVE_STATES:
        raise VmError("stop the VM before deleting it")
    shutil.rmtree(vm_dir(vm_id))
    L.info("deleted VM %s", vm_id)


# ---------------------------------------------------------------- runtime state

def read_state(vm_id):
    return _read_json(file_path(vm_id, "state.json"), {}) or {}


def write_state(vm_id, **changes):
    st = read_state(vm_id)
    st.update(changes)
    st["updated_at"] = time.time()
    _write_json(file_path(vm_id, "state.json"), st)
    return st


def pid_alive(pid, must_contain=None):
    if not pid:
        return False
    try:
        os.kill(int(pid), 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        pass
    try:
        with open("/proc/%d/stat" % int(pid)) as f:
            if f.read().rsplit(")", 1)[1].split()[0] in ("Z", "X"):
                return False  # zombie: exited but not reaped
    except (OSError, IndexError):
        pass
    if must_contain:
        try:
            with open("/proc/%d/cmdline" % int(pid), "rb") as f:
                return must_contain.encode() in f.read()
        except OSError:
            return False
    return True


def status(vm_id):
    """Runtime state with stale-process detection."""
    st = read_state(vm_id)
    state = st.get("state", "stopped")
    if state in ACTIVE_STATES and not pid_alive(st.get("supervisor_pid"), "sailvisor"):
        if pid_alive(st.get("crosvm_pid"), "crosvm"):
            st["note"] = "supervisor died but crosvm is still running"
        else:
            state = "dead"
            st["note"] = "supervisor and crosvm are gone without recording an exit (killed or crashed)"
    st["state"] = state
    if state in ("running", "stopping") and st.get("started_at"):
        st["uptime"] = round(time.time() - st["started_at"], 1)
    return st


def summary(vm_id):
    cfg = load(vm_id)
    st = status(vm_id)
    return {
        "id": vm_id,
        "name": cfg["name"],
        "cpus": cfg["cpus"],
        "memory_mb": cfg["memory_mb"],
        "state": st["state"],
        "guest_ready": bool(st.get("guest_ready")),
        "exit_reason": st.get("exit_reason", ""),
        "uptime": st.get("uptime", 0),
    }


# ---------------------------------------------------------------- crosvm command line

def crosvm_command(cfg, console_sock, control_sock):
    vm_id = cfg["id"]
    cmd = [
        paths.CROSVM,
        "--no-syslog",
        "--extended-status",
        "--log-level", cfg.get("log_level") or "info",
        "run",
        "--hypervisor", "geniezone",
        "--disable-sandbox",
        "--cpus", "num-cores=%d" % int(cfg["cpus"]),
        "--mem", "size=%d" % int(cfg["memory_mb"]),
        "--serial", "type=unix-stream,path=%s,input-unix-stream,console,earlycon" % console_sock,
        "--socket", control_sock,
    ]
    if cfg.get("initrd"):
        cmd += ["--initrd", cfg["initrd"]]
    if cfg.get("cmdline"):
        cmd += ["--params", cfg["cmdline"]]
    for disk in cfg.get("disks", []):
        cmd += ["--block", "path=%s,ro=%s" % (disk["path"], "true" if disk.get("ro") else "false")]
    if cfg.get("iso"):
        cmd += ["--block", "path=%s,ro=true" % cfg["iso"]]
    cmd += list(cfg.get("extra_args") or [])
    cmd.append(cfg["kernel"])
    L.debug("crosvm command for %s: %s", vm_id, cmd)
    return cmd

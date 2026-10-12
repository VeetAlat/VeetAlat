"""Host diagnostics: is this device able to run VMs, and if not, why."""

import fcntl
import os
import platform
import shutil
import stat
import subprocess
import sys

from . import VERSION, log, paths, vm

L = log.get("doctor")

# from crosvm hypervisor/src/geniezone/geniezone_sys (GZVM_IOC_MAGIC = 0x92)
GZVM_CREATE_VM = 0x9201
GZVM_CHECK_EXTENSION = 0x9203
GZVM_CAP_ARM_VM_IPA_SIZE = 165

CPU_PARTS = {"0xd05": "Cortex-A55", "0xd41": "Cortex-A78", "0xd44": "Cortex-X1", "0xd46": "Cortex-A510",
             "0xd47": "Cortex-A710", "0xd48": "Cortex-X2", "0xd4d": "Cortex-A715", "0xd4e": "Cortex-X3",
             "0xd0b": "Cortex-A76", "0xd0d": "Cortex-A77", "0xd03": "Cortex-A53", "0xd08": "Cortex-A72"}


def _read(path, binary=False):
    try:
        with open(path, "rb") as f:
            data = f.read()
        return data if binary else data.decode("utf-8", "replace").strip()
    except OSError:
        return None


def _check(cid, title, status, detail):
    return {"id": cid, "title": title, "status": status, "detail": detail}


def gzvm_probe(device=None):
    """Open the GenieZone device, query the IPA size and create (and drop) an empty VM."""
    device = device or paths.GZVM_DEVICE
    result = {"device": device, "open": False, "ipa_bits": None, "create_vm": False, "error": None}
    try:
        fd = os.open(device, os.O_RDWR | os.O_CLOEXEC)
    except OSError as e:
        result["error"] = "open failed: %s" % e
        return result
    result["open"] = True
    try:
        try:
            result["ipa_bits"] = fcntl.ioctl(fd, GZVM_CHECK_EXTENSION, GZVM_CAP_ARM_VM_IPA_SIZE)
        except OSError as e:
            result["ipa_error"] = str(e)
        try:
            vm_fd = fcntl.ioctl(fd, GZVM_CREATE_VM, 0)
            result["create_vm"] = True
            os.close(vm_fd)
        except OSError as e:
            result["error"] = "GZVM_CREATE_VM failed: %s" % e
    finally:
        os.close(fd)
    return result


def run_checks():
    checks = []

    # platform
    model = _read("/proc/device-tree/model") or "unknown"
    osrel = {}
    for line in (_read("/etc/os-release") or "").splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            osrel[k] = v.strip('"')
    checks.append(_check("platform", "Device", "info",
                         "%s, %s %s, kernel %s (%s), Sailvisor %s, Python %s" % (
                             model.rstrip("\x00"), osrel.get("NAME", "?"), osrel.get("VERSION_ID", "?"),
                             platform.release(), platform.machine(), VERSION, sys.version.split()[0])))

    parts = {}
    for line in (_read("/proc/cpuinfo") or "").splitlines():
        if line.startswith("CPU part"):
            p = line.split(":")[1].strip()
            parts[p] = parts.get(p, 0) + 1
    cpu_desc = ", ".join("%dx %s" % (n, CPU_PARTS.get(p, p)) for p, n in sorted(parts.items())) or "unknown"
    checks.append(_check("cpu", "CPU", "ok" if platform.machine() == "aarch64" else "fail",
                         "%s cores: %s" % (os.cpu_count(), cpu_desc)))

    mem = {}
    for line in (_read("/proc/meminfo") or "").splitlines():
        k, _, v = line.partition(":")
        mem[k] = int(v.split()[0]) // 1024 if v.split() else 0
    avail = mem.get("MemAvailable", 0)
    checks.append(_check("memory", "Memory", "ok" if avail >= 768 else "warn",
                         "%d MiB total, %d MiB available" % (mem.get("MemTotal", 0), avail)))

    # hypervisor
    compat = _read("/proc/device-tree/hypervisor/compatible", binary=True)
    if compat:
        names = [c for c in compat.decode("ascii", "replace").split("\x00") if c]
        checks.append(_check("dt", "Hypervisor in device tree",
                             "ok" if any("geniezone" in n for n in names) else "warn", ", ".join(names)))
    else:
        checks.append(_check("dt", "Hypervisor in device tree", "warn", "no /proc/device-tree/hypervisor node"))

    dev = paths.GZVM_DEVICE
    if os.path.exists(dev):
        s = os.stat(dev)
        checks.append(_check("gzvm_dev", "GenieZone device", "ok",
                             "%s %s uid=%d gid=%d" % (dev, stat.filemode(s.st_mode), s.st_uid, s.st_gid)))
        probe = gzvm_probe(dev)
        if probe["create_vm"]:
            checks.append(_check("gzvm_vm", "GenieZone VM creation", "ok",
                                 "created and released an empty VM; guest IPA size %s bits"
                                 % (probe["ipa_bits"] if probe["ipa_bits"] else "default (40)")))
        else:
            checks.append(_check("gzvm_vm", "GenieZone VM creation", "fail", probe["error"]))
    else:
        checks.append(_check("gzvm_dev", "GenieZone device", "fail", "%s not found" % dev))

    checks.append(_check("kvm", "KVM", "info",
                         "/dev/kvm present (not used by Sailvisor)" if os.path.exists("/dev/kvm")
                         else "/dev/kvm absent (expected: GenieZone owns EL2)"))

    # crosvm
    if os.access(paths.CROSVM, os.X_OK):
        try:
            out = subprocess.run([paths.CROSVM, "--no-syslog", "version"], stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, timeout=15)
            txt = out.stdout.decode("utf-8", "replace").strip().splitlines()
            ver = next((l for l in txt if l.startswith("crosvm")), txt[0] if txt else "?")
            checks.append(_check("crosvm", "crosvm", "ok" if out.returncode == 0 else "fail",
                                 "%s (%s, %.1f MB)" % (ver, paths.CROSVM, os.path.getsize(paths.CROSVM) / 1e6)))
        except (OSError, subprocess.TimeoutExpired) as e:
            checks.append(_check("crosvm", "crosvm", "fail", "cannot run %s: %s" % (paths.CROSVM, e)))
    else:
        checks.append(_check("crosvm", "crosvm", "fail", "%s missing or not executable" % paths.CROSVM))

    # bundled guest
    missing = [p for p in (paths.TEST_KERNEL, paths.TEST_INITRD) if not os.path.isfile(p)]
    if missing:
        checks.append(_check("guest", "Test guest", "warn", "missing: %s" % ", ".join(missing)))
    else:
        kver = _read(os.path.join(paths.GUEST_DIR, "kernel-version")) or "?"
        checks.append(_check("guest", "Test guest", "ok", "kernel %s + busybox initramfs" % kver))

    # storage
    d = paths.data_dir()
    free = shutil.disk_usage(d).free // (1024 * 1024)
    checks.append(_check("storage", "Storage", "ok" if free > 1024 else "warn",
                         "%s, %d MiB free" % (d, free)))

    # kernel log
    try:
        out = subprocess.run(["dmesg"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
        if out.returncode == 0:
            lines = [l for l in out.stdout.decode("utf-8", "replace").splitlines()
                     if any(k in l.lower() for k in ("gzvm", "geniezone", "started at el", "hyp mode"))]
            checks.append(_check("dmesg", "Kernel log", "info",
                                 "\n".join(lines[-8:]) if lines else "no GenieZone lines (log may have rotated)"))
        else:
            checks.append(_check("dmesg", "Kernel log", "info",
                                 "not readable as this user (run `devel-su dmesg | grep -i gzvm`)"))
    except (OSError, subprocess.TimeoutExpired) as e:
        checks.append(_check("dmesg", "Kernel log", "info", "dmesg unavailable: %s" % e))

    # VMs
    states = {}
    for vm_id in vm.list_ids():
        s = vm.status(vm_id)["state"]
        states[s] = states.get(s, 0) + 1
    checks.append(_check("vms", "Virtual machines", "info",
                         ", ".join("%d %s" % (n, s) for s, n in sorted(states.items())) or "none yet"))

    for c in checks:
        L.debug("check %s: %s - %s", c["id"], c["status"], c["detail"])
    return checks


def overall(checks):
    statuses = [c["status"] for c in checks]
    return "fail" if "fail" in statuses else "warn" if "warn" in statuses else "ok"

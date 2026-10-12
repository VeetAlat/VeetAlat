"""API for the QML UI (via PyOtherSide).

Every function returns {"ok": True, "result": ...} or {"ok": False, "error": "..."} so the UI can show
errors instead of failing silently; failures are logged with a traceback.
"""

import functools
import traceback

from . import VERSION, control, doctor, iso, log, paths, report, vm

log.setup()
L = log.get("bridge")
L.info("Sailvisor %s UI backend loaded (data dir %s)", VERSION, paths.data_dir())


def api(fn):
    @functools.wraps(fn)
    def wrapper(*args):
        try:
            result = fn(*args)
            return {"ok": True, "result": result}
        except (vm.VmError, iso.IsoError) as e:
            L.warning("%s%r failed: %s", fn.__name__, args, e)
            return {"ok": False, "error": str(e)}
        except Exception as e:
            L.error("%s%r crashed:\n%s", fn.__name__, args, traceback.format_exc())
            return {"ok": False, "error": "%s: %s" % (type(e).__name__, e)}
    return wrapper


@api
def info():
    return {"version": VERSION, "data_dir": paths.data_dir(), "crosvm": paths.CROSVM,
            "app_log": log.app_log_path(), "test_kernel": paths.TEST_KERNEL, "test_initrd": paths.TEST_INITRD}


@api
def set_debug(enabled):
    log.setup(verbose=bool(enabled))
    import logging
    logging.getLogger("sailvisor").setLevel(logging.DEBUG if enabled else logging.INFO)
    L.info("debug logging %s", "enabled" if enabled else "disabled")
    return bool(enabled)


@api
def list_vms():
    return [vm.summary(i) for i in vm.list_ids()]


@api
def get_vm(vm_id):
    cfg = vm.load(vm_id)
    st = vm.status(vm_id)
    return {"config": cfg, "status": st, "problems": control.preflight(cfg),
            "command": vm.crosvm_command(cfg, vm.file_path(vm_id, "console.sock"), vm.file_path(vm_id, "ctl.sock"))}


@api
def create_vm(fields):
    return vm.create(fields)


@api
def create_test_vm(mode):
    return vm.create({
        "name": "Test guest",
        "kernel": paths.TEST_KERNEL,
        "initrd": paths.TEST_INITRD,
        "memory_mb": 256,
        "cmdline": "panic=-1 sailvisor.mode=%s" % (mode or "heartbeat"),
        "notes": "Bundled busybox guest. Modes: heartbeat, shell, poweroff (sailvisor.mode= in cmdline).",
    })


@api
def update_vm(vm_id, fields):
    vm.update(vm_id, fields)
    return vm_id


@api
def delete_vm(vm_id):
    vm.delete(vm_id)
    return vm_id


@api
def start_vm(vm_id):
    return control.start(vm_id)


@api
def stop_vm(vm_id):
    return control.stop(vm_id)


@api
def kill_vm(vm_id):
    return control.kill(vm_id)


@api
def status(vm_id):
    return vm.status(vm_id)


@api
def console_tail(vm_id, max_bytes):
    return control.tail_file(vm.file_path(vm_id, "console.log"), int(max_bytes or 32768))


@api
def log_tail(vm_id, name, max_bytes):
    if name not in ("vm.log", "vm.log.1", "console.log.1", "supervisor.err"):
        raise vm.VmError("unknown log %s" % name)
    return control.tail_file(vm.file_path(vm_id, name), int(max_bytes or 65536))


@api
def app_log_tail(max_bytes):
    return control.tail_file(log.app_log_path(), int(max_bytes or 65536))


@api
def send_console(vm_id, text):
    control.send_console(vm_id, text)
    return len(text)


@api
def run_doctor():
    checks = doctor.run_checks()
    return {"overall": doctor.overall(checks), "checks": checks}


@api
def selftest_start():
    vm_id = control.ensure_selftest_vm()
    control.start(vm_id)
    return vm_id


@api
def selftest_result():
    return control.selftest_result()


@api
def save_report():
    return report.save()


@api
def inspect_iso(path):
    return iso.inspect(path)


@api
def import_iso(path, name, memory_mb):
    vm_id, info_ = iso.import_iso(path, name or None, int(memory_mb or 2048))
    return {"id": vm_id, "info": info_}

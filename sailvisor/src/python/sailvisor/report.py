"""Debug report: one text file with everything needed to diagnose a problem."""

import json
import os
import time

from . import VERSION, control, doctor, log, paths, vm

L = log.get("report")


def _section(out, title):
    out.append("\n" + "=" * 72)
    out.append(title)
    out.append("=" * 72)


def build():
    out = ["Sailvisor debug report", "version: %s" % VERSION,
           "created: %s" % time.strftime("%Y-%m-%d %H:%M:%S %z")]

    _section(out, "DIAGNOSTICS")
    checks = doctor.run_checks()
    for c in checks:
        out.append("[%-4s] %s: %s" % (c["status"].upper(), c["title"], c["detail"]))

    for vm_id in vm.list_ids():
        _section(out, "VM %s" % vm_id)
        try:
            out.append("config: " + json.dumps(vm.load(vm_id), indent=2, sort_keys=True))
            out.append("state: " + json.dumps(vm.status(vm_id), indent=2, sort_keys=True))
        except Exception as e:
            out.append("cannot read VM: %s" % e)
        for name, size in (("vm.log", 24000), ("console.log", 16000), ("supervisor.err", 4000),
                           ("vm.log.1", 8000), ("console.log.1", 4000)):
            text = control.tail_file(vm.file_path(vm_id, name), size)
            if text:
                out.append("\n--- %s (last %d bytes) ---" % (name, size))
                out.append(text.rstrip())

    _section(out, "APP LOG")
    out.append(control.tail_file(log.app_log_path(), 64000).rstrip())
    return "\n".join(out) + "\n"


def save():
    path = os.path.join(paths.reports_dir(), "sailvisor-report-%s.txt" % time.strftime("%Y%m%d-%H%M%S"))
    with open(path, "w") as f:
        f.write(build())
    L.info("debug report written to %s", path)
    return path

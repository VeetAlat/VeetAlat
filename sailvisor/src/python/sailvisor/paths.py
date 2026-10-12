"""Filesystem locations. Every path can be overridden with an environment variable for testing."""

import os

SHARE_DIR = os.environ.get("SAILVISOR_SHARE", "/usr/share/sailvisor")
CROSVM = os.environ.get("SAILVISOR_CROSVM", "/usr/libexec/sailvisor/crosvm")
GZVM_DEVICE = os.environ.get("SAILVISOR_GZVM", "/dev/gzvm")
GUEST_DIR = os.path.join(SHARE_DIR, "guest")
TEST_KERNEL = os.path.join(GUEST_DIR, "Image")
TEST_INITRD = os.path.join(GUEST_DIR, "initrd.img")
PYTHON_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def data_dir():
    base = os.environ.get("SAILVISOR_DATA")
    if not base:
        xdg = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
        base = os.path.join(xdg, "sailvisor")
    os.makedirs(base, exist_ok=True)
    return base


def vms_dir():
    d = os.path.join(data_dir(), "vms")
    os.makedirs(d, exist_ok=True)
    return d


def logs_dir():
    d = os.path.join(data_dir(), "logs")
    os.makedirs(d, exist_ok=True)
    return d


def reports_dir():
    docs = os.path.expanduser("~/Documents")
    d = os.path.join(docs, "Sailvisor") if os.path.isdir(docs) else os.path.join(data_dir(), "reports")
    os.makedirs(d, exist_ok=True)
    return d

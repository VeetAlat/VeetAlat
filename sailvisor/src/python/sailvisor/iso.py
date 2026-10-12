"""Experimental ISO support.

crosvm boots a kernel directly (no UEFI firmware here), so "booting an ISO" means: read the ISO 9660
filesystem, find the distribution's kernel and initrd, extract them, and attach the ISO itself as a
read-only disk so the live system finds its root filesystem on it.
"""

import os
import struct
import zlib
import bz2
import lzma

from . import log, vm

L = log.get("iso")

SECTOR = 2048

# (profile, kernel path prefixes, initrd path prefixes, kernel cmdline); {label} = volume id
PROFILES = [
    ("Ubuntu live", ["casper/vmlinuz"], ["casper/initrd"], "boot=casper console=ttyS0"),
    ("Debian live", ["live/vmlinuz"], ["live/initrd"], "boot=live components console=ttyS0"),
    ("Debian installer", ["install.a64/vmlinuz", "install/vmlinuz"], ["install.a64/initrd", "install/initrd"],
     "console=ttyS0"),
    ("Alpine", ["boot/vmlinuz-virt", "boot/vmlinuz-lts"], ["boot/initramfs-virt", "boot/initramfs-lts"],
     "modules=loop,squashfs,sd-mod,virtio_blk,virtio_pci console=ttyS0"),
    ("Fedora live", ["images/pxeboot/vmlinuz"], ["images/pxeboot/initrd"],
     "root=live:CDLABEL={label} rd.live.image console=ttyS0"),
    ("Generic", ["boot/vmlinuz", "vmlinuz", "boot/image$", "image$"], ["boot/initrd", "initrd", "boot/initramfs"],
     "console=ttyS0"),
]


def _find(files, prefixes):
    """First file matching a prefix (case-insensitive); a trailing '$' means exact match."""
    for pre in prefixes:
        for p in sorted(files):
            low = p.lower()
            if (low == pre[:-1]) if pre.endswith("$") else low.startswith(pre):
                return p
    return None


class IsoError(Exception):
    pass


class Iso9660:
    def __init__(self, path):
        self.path = path
        self.f = open(path, "rb")
        pvd = self._read(16 * SECTOR, SECTOR)
        if pvd[0:1] != b"\x01" or pvd[1:6] != b"CD001":
            raise IsoError("not an ISO 9660 image (no primary volume descriptor)")
        self.label = pvd[40:72].decode("ascii", "replace").strip()
        self.root = self._parse_record(pvd[156:190])

    def close(self):
        self.f.close()

    def _read(self, offset, size):
        self.f.seek(offset)
        return self.f.read(size)

    @staticmethod
    def _rock_ridge_name(su):
        name, i = b"", 0
        while i + 4 <= len(su):
            sig, length = su[i:i + 2], su[i + 2]
            if length < 4:
                break
            if sig == b"NM":
                name += su[i + 5:i + length]
            i += length
        return name.decode("utf-8", "replace") if name else None

    def _parse_record(self, rec):
        name_len = rec[32]
        raw = rec[33:33 + name_len]
        su_start = 33 + name_len + (1 - name_len % 2)
        rr = self._rock_ridge_name(rec[su_start:rec[0]])
        if raw in (b"\x00", b"\x01"):
            name = "." if raw == b"\x00" else ".."
        elif rr:
            name = rr
        else:
            name = raw.decode("ascii", "replace").split(";")[0].rstrip(".").lower()
        return {"name": name, "lba": struct.unpack_from("<I", rec, 2)[0],
                "size": struct.unpack_from("<I", rec, 10)[0], "dir": bool(rec[25] & 2)}

    def listdir(self, entry):
        data = self._read(entry["lba"] * SECTOR, entry["size"])
        out, i = [], 0
        while i < len(data):
            length = data[i]
            if length == 0:  # records never cross sectors: skip padding
                i = (i // SECTOR + 1) * SECTOR
                continue
            rec = self._parse_record(data[i:i + length])
            if rec["name"] not in (".", ".."):
                out.append(rec)
            i += length
        return out

    def walk(self, max_depth=3):
        files, stack = {}, [("", self.root, 0)]
        while stack:
            prefix, entry, depth = stack.pop()
            for child in self.listdir(entry):
                path = prefix + child["name"]
                if child["dir"]:
                    if depth + 1 < max_depth:
                        stack.append((path + "/", child, depth + 1))
                else:
                    files[path] = child
        return files

    def read_file(self, entry):
        return self._read(entry["lba"] * SECTOR, entry["size"])


def decode_kernel(data):
    """Return a raw arm64 Image from gzip/xz/bzip2 or EFI zboot packed kernels."""
    def inflate(payload, comp):
        if comp == "gzip":
            return zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(payload)
        if comp in ("xzkern", "xz", "lzma"):
            return lzma.decompress(payload)
        if comp == "bzip2":
            return bz2.decompress(payload)
        raise IsoError("kernel compressed with %s, which Sailvisor cannot unpack yet" % comp)

    if data[:2] == b"\x1f\x8b":
        data = inflate(data, "gzip")
    elif data[:6] == b"\xfd7zXZ\x00":
        data = inflate(data, "xz")
    elif data[:2] == b"MZ" and data[4:8] == b"zimg":
        off, size = struct.unpack_from("<II", data, 8)
        comp = data[24:32].rstrip(b"\x00").decode("ascii", "replace")
        data = inflate(data[off:off + size], comp)
    if len(data) < 64 or data[56:60] != b"ARM\x64":
        raise IsoError("kernel is not an arm64 Linux Image (is this an x86 ISO?)")
    return data


def inspect(path):
    iso = Iso9660(path)
    try:
        files = iso.walk()
        for profile, kprefixes, iprefixes, cmdline in PROFILES:
            kernel = _find(files, kprefixes)
            if not kernel:
                continue
            initrd = _find(files, iprefixes)
            return {"label": iso.label, "profile": profile, "kernel": kernel, "initrd": initrd,
                    "cmdline": cmdline.replace("{label}", iso.label.replace(" ", "\\x20")),
                    "files": len(files)}
        raise IsoError("no Linux kernel found in %s (looked for %s)" % (
            os.path.basename(path), ", ".join(p.rstrip("$") for _, ks, _, _ in PROFILES for p in ks)))
    finally:
        iso.close()


def import_iso(path, name=None, memory_mb=2048, cpus=1):
    path = os.path.abspath(path)
    info = inspect(path)
    L.info("ISO %s: %s", path, info)
    vm_id = vm.create({
        "name": name or info["label"] or os.path.basename(path),
        "cpus": cpus, "memory_mb": memory_mb, "iso": path,
        "cmdline": info["cmdline"],
        "notes": "Imported from %s (%s profile, kernel %s, initrd %s)" % (
            os.path.basename(path), info["profile"], info["kernel"], info["initrd"] or "none"),
    })
    try:
        iso = Iso9660(path)
        try:
            files = iso.walk()
            kernel_path = vm.file_path(vm_id, "kernel.Image")
            with open(kernel_path, "wb") as f:
                f.write(decode_kernel(iso.read_file(files[info["kernel"]])))
            fields = {"kernel": kernel_path}
            if info["initrd"]:
                initrd_path = vm.file_path(vm_id, "initrd")
                with open(initrd_path, "wb") as f:
                    f.write(iso.read_file(files[info["initrd"]]))
                fields["initrd"] = initrd_path
        finally:
            iso.close()
        vm.update(vm_id, fields)
    except Exception:
        vm.delete(vm_id)
        raise
    return vm_id, info

#!/bin/bash
# Builds the bundled test guest: an Ubuntu arm64 kernel Image and a tiny busybox initramfs.
# Usage: guest/build-guest.sh <outdir>
set -euo pipefail

OUT=$(realpath -m "${1:-build/guest}")
HERE=$(cd "$(dirname "$0")" && pwd)
PORTS=https://ports.ubuntu.com/ubuntu-ports
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

for dist in noble-updates noble; do
    curl -fsS "$PORTS/dists/$dist/main/binary-arm64/Packages.xz" | xz -d > "$WORK/Packages-$dist"
done

pkg_url() {  # pkg_url <package> -> pool URL of the package, preferring noble-updates
    local f
    f=$(awk -v p="$1" '$1=="Package:"{hit=($2==p)} hit && $1=="Filename:"{print $2; exit}' \
        "$WORK/Packages-noble-updates")
    [ -n "$f" ] || f=$(awk -v p="$1" '$1=="Package:"{hit=($2==p)} hit && $1=="Filename:"{print $2; exit}' \
        "$WORK/Packages-noble")
    [ -n "$f" ] || { echo "package $1 not found" >&2; exit 1; }
    echo "$PORTS/$f"
}

KPKG=$(awk '$1=="Package:" && $2 ~ /^linux-image-unsigned-6\.8\.0-[0-9]+-generic$/ {print $2}' \
    "$WORK/Packages-noble-updates" | sort -V | tail -1)
echo "kernel package: $KPKG"
curl -fsSL -o "$WORK/kernel.deb" "$(pkg_url "$KPKG")"
curl -fsSL -o "$WORK/busybox.deb" "$(pkg_url busybox-static)"

dpkg-deb -x "$WORK/kernel.deb" "$WORK/k"
dpkg-deb -x "$WORK/busybox.deb" "$WORK/bb"

# crosvm wants a raw arm64 Image, Ubuntu ships it gzip-compressed
zcat "$WORK"/k/boot/vmlinuz-* > "$OUT/Image"
python3 - "$OUT/Image" <<'EOF'
import sys
with open(sys.argv[1], 'rb') as f:
    hdr = f.read(64)
assert hdr[56:60] == b'ARM\x64', 'not an arm64 Image'
print('Image OK:', sys.argv[1])
EOF
basename "$WORK"/k/boot/vmlinuz-* | sed 's/^vmlinuz-//' > "$OUT/kernel-version"

R="$WORK/root"
mkdir -p "$R/bin" "$R/dev"
# the kernel opens /dev/console for PID 1 before devtmpfs is mounted
mknod -m 600 "$R/dev/console" c 5 1
cp "$WORK/bb/usr/bin/busybox" "$R/bin/busybox"
install -m 0755 "$HERE/init" "$R/init"
(cd "$R" && find . | cpio --quiet -o -H newc -R 0:0 | gzip -9) > "$OUT/initrd.img"
echo "initrd OK: $OUT/initrd.img ($(du -h "$OUT/initrd.img" | cut -f1))"

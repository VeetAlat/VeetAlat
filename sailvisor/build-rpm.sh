#!/bin/bash
# Builds the Sailvisor aarch64 RPM.
#   ./build-rpm.sh                      build everything (crosvm, test guest, RPM) under ./build
#   CROSVM=/path/to/crosvm ./build-rpm.sh   reuse an existing crosvm binary
#   GUEST=/path/to/guest-dir ./build-rpm.sh reuse an existing guest (Image, initrd.img, kernel-version)
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$PWD
BUILD=$ROOT/build
VERSION=$(sed -n 's/^Version: *//p' rpm/sailvisor.spec)
mkdir -p "$BUILD"

CROSVM=${CROSVM:-$BUILD/crosvm}
[ -x "$CROSVM" ] || scripts/build-crosvm.sh "$BUILD/crosvm-src" "$CROSVM"
GUEST=${GUEST:-$BUILD/guest}
[ -f "$GUEST/Image" ] || guest/build-guest.sh "$GUEST"

STAGE=$BUILD/stage
rm -rf "$STAGE"
install -Dm0755 "$CROSVM" "$STAGE/usr/libexec/sailvisor/crosvm"
if [ -f "$CROSVM.commit" ]; then cp "$CROSVM.commit" "$STAGE/usr/libexec/sailvisor/crosvm.commit"
else echo unknown > "$STAGE/usr/libexec/sailvisor/crosvm.commit"; fi
install -Dm0755 src/sailvisor-cli "$STAGE/usr/bin/sailvisor-cli"
install -Dm0644 src/sailvisor.desktop "$STAGE/usr/share/applications/sailvisor.desktop"
mkdir -p "$STAGE/usr/share/sailvisor/python" "$STAGE/usr/share/sailvisor/guest"
cp -r src/qml "$STAGE/usr/share/sailvisor/qml"
cp -r src/python/sailvisor "$STAGE/usr/share/sailvisor/python/sailvisor"
find "$STAGE" -name __pycache__ -prune -exec rm -rf {} +
install -m0644 "$GUEST/Image" "$GUEST/initrd.img" "$GUEST/kernel-version" "$STAGE/usr/share/sailvisor/guest/"
for s in 86 108 128 172; do
    install -Dm0644 "icons/png/sailvisor-$s.png" "$STAGE/usr/share/icons/hicolor/${s}x${s}/apps/sailvisor.png"
done

rpmbuild -bb --target aarch64-linux \
    --define "_topdir $BUILD/rpmbuild" \
    --define "stagedir $STAGE" \
    rpm/sailvisor.spec
RPM=$(ls -t "$BUILD"/rpmbuild/RPMS/aarch64/sailvisor-"$VERSION"-*.aarch64.rpm | head -1)
cp "$RPM" "$BUILD/"
echo "built: $BUILD/$(basename "$RPM")"

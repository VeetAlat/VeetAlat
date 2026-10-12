#!/bin/bash
# Cross-compiles crosvm for Sailfish OS (aarch64) with the GenieZone backend, statically linked.
# Tested on Ubuntu 24.04 x86_64. Usage: scripts/build-crosvm.sh <workdir> <output-binary>
set -euo pipefail

WORK=$(realpath -m "${1:-build/crosvm-src}")
OUT=$(realpath -m "${2:-build/crosvm}")
PORTS=https://ports.ubuntu.com/ubuntu-ports

sudo_if() { if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi; }
sudo_if apt-get install -y -qq gcc-aarch64-linux-gnu g++-aarch64-linux-gnu clang libclang-dev pkg-config make

mkdir -p "$WORK"
if [ ! -d "$WORK/crosvm" ]; then
    git clone --depth 1 https://github.com/google/crosvm "$WORK/crosvm"
fi
cd "$WORK/crosvm"
# minijail is a submodule hosted on googlesource; use the GitHub mirror at the pinned commit
MJ=$(git ls-tree HEAD third_party/minijail | awk '{print $3}')
if [ ! -f third_party/minijail/libminijail.c ]; then
    rm -rf third_party/minijail
    git clone -q https://github.com/google/minijail third_party/minijail
fi
git -C third_party/minijail checkout -q "$MJ"

# arm64 libcap for minijail (headers + static lib) into a private sysroot
SYSROOT="$WORK/sysroot"
if [ ! -f "$SYSROOT/usr/lib/aarch64-linux-gnu/libcap.a" ]; then
    mkdir -p "$SYSROOT" "$WORK/debs"
    curl -fsS "$PORTS/dists/noble-updates/main/binary-arm64/Packages.xz" | xz -d > "$WORK/debs/Packages"
    for p in libcap-dev libcap2; do
        f=$(awk -v p="$p" '$1=="Package:"{hit=($2==p)} hit && $1=="Filename:"{print $2; exit}' "$WORK/debs/Packages")
        curl -fsSL -o "$WORK/debs/$p.deb" "$PORTS/$f"
        dpkg-deb -x "$WORK/debs/$p.deb" "$SYSROOT"
    done
fi

TOOLCHAIN=$(sed -n 's/^channel = "\(.*\)"/\1/p' rust-toolchain)
rustup toolchain install "$TOOLCHAIN" --profile minimal
rustup target add aarch64-unknown-linux-gnu --toolchain "$TOOLCHAIN"

export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
export CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc
export CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++
export AR_aarch64_unknown_linux_gnu=aarch64-linux-gnu-ar
export PKG_CONFIG_ALLOW_CROSS=1 PKG_CONFIG_PATH= PKG_CONFIG_LIBDIR=/nonexistent
export CPPFLAGS="-I$SYSROOT/usr/include" LDFLAGS="-L$SYSROOT/usr/lib/aarch64-linux-gnu"
export MINIJAIL_BINDGEN_TARGET=aarch64-linux-gnu
export BINDGEN_EXTRA_CLANG_ARGS="--sysroot=/usr/aarch64-linux-gnu -I$SYSROOT/usr/include"
# static: Sailfish's glibc is older than the cross toolchain's
export RUSTFLAGS="-C target-feature=+crt-static -L native=$SYSROOT/usr/lib/aarch64-linux-gnu"

cargo build --release --target aarch64-unknown-linux-gnu --no-default-features --features geniezone
mkdir -p "$(dirname "$OUT")"
aarch64-linux-gnu-strip -o "$OUT" target/aarch64-unknown-linux-gnu/release/crosvm
echo "crosvm built: $OUT ($(git rev-parse --short HEAD))"
git rev-parse HEAD > "$OUT.commit"

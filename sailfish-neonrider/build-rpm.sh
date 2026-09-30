#!/bin/sh
#
# Builds the RPM with the community Sailfish SDK Docker image, no SDK
# install needed. Usage: ./build-rpm.sh [aarch64|armv7hl|i486]
# The package lands in RPMS/.

set -eu

SDK_VERSION=4.6.0.13 # oldest target we build for; the result runs on 5.x too
ARCH=${1:-aarch64}
HERE=$(cd "$(dirname "$0")" && pwd)

docker run --rm -v "$HERE:/home/mersdk/src" -w /home/mersdk/src \
    "coderus/sailfishos-platform-sdk:$SDK_VERSION" \
    mb2 -t "SailfishOS-$SDK_VERSION-$ARCH" build

#!/bin/sh
#
# Builds the patch's RPM (noarch) with the community Sailfish SDK Docker
# image. The package lands in RPMS/.

set -eu

SDK_VERSION=4.6.0.13
HERE=$(cd "$(dirname "$0")" && pwd)

docker run --rm -v "$HERE:/home/mersdk/src" -w /home/mersdk/src \
    "coderus/sailfishos-platform-sdk:$SDK_VERSION" \
    mb2 -t "SailfishOS-$SDK_VERSION-aarch64" build

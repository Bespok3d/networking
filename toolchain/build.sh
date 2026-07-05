#!/bin/sh
# Cross-build tun.ko for the U1 kernel (Linux 6.1.99 aarch64) into dist/tun.ko, then verify its
# vermagic. Modeled on plugins/u1-hw-camera/toolchain/build.sh. The vermagic check is necessary,
# NOT sufficient (MODVERSIONS is off, so there is no CRC safety net): the real gate is an on-device
# insmod on junior plus exercising /dev/net/tun, per the recon. See doc/recon-kernel-vpn.md.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
. "$SCRIPT_DIR/lib/docker-build.sh"

if ! command -v docker > /dev/null 2>&1; then
    echo "ERROR: docker not found"
    exit 1
fi

# What insmod on junior's running kernel accepts. Every token comes from junior's .config + the
# pinned 6.1.99 source: version 6.1.99, SMP, preempt (not _RT), mod_unload, aarch64.
EXPECTED_VERMAGIC="6.1.99 SMP preempt mod_unload aarch64"

echo "==> Cross-building tun.ko for the U1 kernel (6.1.99 aarch64, ARM 10.3-2021.07 toolchain)..."
rm -rf dist
# Context is the toolchain dir so the Dockerfile's `COPY junior-6.1.99.config` resolves.
docker_image bespok3d-tun-module "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"

echo "==> Extracting tun.ko to dist/..."
docker_extract bespok3d-tun-module bespok3d-tun-module-tmp

if [ ! -f dist/tun.ko ]; then
    echo "ERROR: dist/tun.ko missing. Check the Docker build output."
    exit 1
fi

echo "==> Verifying vermagic (necessary, not sufficient: the device insmod is the real gate)..."
vermagic=$(docker run --rm --entrypoint modinfo bespok3d-tun-module -F vermagic /out/tun.ko | tr -d '\r')
echo "  vermagic: $vermagic"
if [ "$vermagic" != "$EXPECTED_VERMAGIC" ]; then
    echo "ERROR: vermagic mismatch."
    echo "  expected: $EXPECTED_VERMAGIC"
    echo "  built:    $vermagic"
    echo "  A mismatch means the source point or config drifted; do NOT ship this .ko."
    exit 1
fi

echo ""
echo "Build complete: $(ls -lh dist/tun.ko | awk '{print $5, $NF}')"
echo "  vermagic OK. Next: place as the 6.1.99 variant and device-verify on junior."

#!/bin/sh
# One-command local build: cross-build tun.ko (via Docker) then pack the .b3. The convenient entry
# point; it chains the two steps CI also runs:
#   1. toolchain/build.sh -> cross-builds tun.ko into toolchain/dist/ (needs Docker; the U1 kernel,
#      built with the ARM cross-toolchain on a linux/amd64 image)
#   2. scripts/pack.sh     -> stages the .ko and zips dist/tun-module-<version>.b3
# The index atom (scripts/generate-atom.mjs) is produced by CI with the real release URL; run it by
# hand only for a local dry run.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> [1/2] Cross-building tun.ko (Docker)"
sh "$REPO_DIR/toolchain/build.sh"

echo "==> [2/2] Packing the .b3"
sh "$SCRIPT_DIR/pack.sh"

echo "==> Done. The .b3 is in dist/."

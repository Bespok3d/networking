#!/bin/sh
# Fetch Tailscale's official static arm64 tarball (SHA-pinned) and extract tailscaled + tailscale
# into files/bin. Modeled on plugins/networking/zerotier/build.sh, but Tailscale (unlike ZeroTier)
# really does publish static Linux binaries per architecture (confirmed by browsing
# pkgs.tailscale.com/stable/ directly): both binaries are statically-linked Go executables (no
# glibc dependency at all, verified with `file` against the real extracted binaries), so there is
# no equivalent of ZeroTier's glibc-compatibility caveat here. Run in CI; never on the printer.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HERE/files/bin"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$BIN"

. "$HERE/../scripts/lib/verify-sha256.sh"

TS_VERSION="1.98.8"
TS_URL="https://pkgs.tailscale.com/stable/tailscale_${TS_VERSION}_arm64.tgz"
TS_SHA="53eb3ce89d062fd34e393d24a6c8ec08c769fede8eb77fe9c6e347ad4ae00f84"

curl -fsSL "$TS_URL" -o "$WORK/tailscale.tgz"
verify_sha256 "$WORK/tailscale.tgz" "$TS_SHA"

tar -xzf "$WORK/tailscale.tgz" -C "$WORK"
install -m 0755 "$WORK/tailscale_${TS_VERSION}_arm64/tailscaled" "$BIN/tailscaled-aarch64"
install -m 0755 "$WORK/tailscale_${TS_VERSION}_arm64/tailscale" "$BIN/tailscale-aarch64"
install -m 0755 "$HERE/src/ts-run" "$BIN/ts-run"

echo "baked tailscaled + tailscale ${TS_VERSION} (aarch64, static) + ts-run into files/bin"

#!/bin/sh
# Fetch ZeroTier's official arm64 .deb (SHA-pinned) and extract the zerotier-one binary into
# files/bin. Modeled on plugins/u1-extras/system-utils/build.sh. No compile: a .deb is an `ar`
# archive of a data.tar.xz that already carries the real aarch64 binary Debian/Ubuntu ship, so
# extracting it needs only `ar` and `tar`, not dpkg. Run in CI; never on the printer.
#
# zerotier-cli and zerotier-idtool are plain symlinks to zerotier-one in the upstream package (the
# same binary dispatches on argv[0], or on -q/-i regardless of name, see zerotier-one(8)); shipping
# only the one binary and invoking `zerotier-one -q ...` for CLI-style calls avoids carrying dead
# symlinks through the .b3 zip, which does not preserve them.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HERE/files/bin"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$BIN"

. "$HERE/../scripts/lib/verify-sha256.sh"

ZT_VERSION="1.16.2"
ZT_URL="https://download.zerotier.com/RELEASES/${ZT_VERSION}/dist/debian/bookworm/zerotier-one_${ZT_VERSION}_arm64.deb"
ZT_SHA="f301d9dac63fad57e8efe90d1221e740ece7e2c70ebda1684915fd7cb00cdc54"

curl -fsSL "$ZT_URL" -o "$WORK/zerotier-one.deb"
verify_sha256 "$WORK/zerotier-one.deb" "$ZT_SHA"

(cd "$WORK" && ar x zerotier-one.deb && tar -xf data.tar.xz)
install -m 0755 "$WORK/usr/sbin/zerotier-one" "$BIN/zerotier-one-aarch64"
install -m 0755 "$HERE/src/zt-run" "$BIN/zt-run"

echo "baked zerotier-one ${ZT_VERSION} (aarch64) + zt-run into files/bin"

#!/bin/sh
# Cross-build tun.ko (Docker; see toolchain/build.sh) and stage it where the manifest's
# kernel-module variant expects it. Run by the co-repo's generic per-plugin build step
# (scripts/pack.sh packs whatever build.sh already staged into files/).
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"

sh "$HERE/toolchain/build.sh"

built="$HERE/toolchain/dist/tun.ko"
if [ ! -f "$built" ]; then
  echo "ERROR: missing $built after toolchain/build.sh." >&2
  exit 1
fi

variant=$(jq -r '(.install.place // [])[]
  | select(.class == "kernel-module")
  | (.variants // [])[].src' "$HERE/manifest.json" | head -n1)
if [ -z "$variant" ]; then
  echo "ERROR: manifest declares no kernel-module variant src to stage into." >&2
  exit 1
fi

rm -rf "$HERE/files/modules"
mkdir -p "$(dirname "$HERE/$variant")"
cp "$built" "$HERE/$variant"
echo "Staged: $HERE/$variant"

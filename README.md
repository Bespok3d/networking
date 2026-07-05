# networking

The Bespok3d networking co-repo: mesh-VPN plugins and the kernel base they build on.

| Plugin | What it is |
| --- | --- |
| `tun-module` | Carries a cross-built `tun.ko` and loads it, so the printer has a working `/dev/net/tun`. The base a mesh VPN needs. See `plugin/doc/README.md`. |

ZeroTier and Tailscale plugins land here in later relay packets; both `require: tun`, so installing
either pulls `tun-module` in first.

## Building the `tun.ko`

The module is a build artifact, not committed source. `toolchain/build.sh` cross-builds it against
the U1's exact kernel (Docker; see `toolchain/Dockerfile`) and drops it in `toolchain/dist/`; the
packer stages it into the `.b3`. CI runs the build on a push that touches the plugin or toolchain
(`.github/workflows/release.yml`, modeled on the `u1-hw-camera` toolchain). The build validates the
module's `vermagic`; the real gate is an on-device `insmod` on a printer.

The one honest caveat is in `plugin/doc/README.md`: the U1 kernel has `CONFIG_MODVERSIONS` off, so a
`vermagic` match is necessary but not sufficient, and a module is trusted only after it loads on the
device and `/dev/net/tun` is exercised.

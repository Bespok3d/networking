# Linux `tun` driver

A separate work, aggregated with this repository. Not covered by this repository's licence.

| | |
| --- | --- |
| Upstream | <https://github.com/rockchip-linux/kernel> |
| Copyright | the Linux kernel contributors |
| Source commit | `8533b2249e1550b233a4836d039d64e3bb2fed7a` |
| Kernel release | 6.1.99, aarch64, Rockchip RK3562 vendor tree |
| Licence text retrieved | 2026-07-28 |
| Licence | GPL-2.0-only, in [LICENSE](LICENSE) |

## What it is

The kernel's `tun` driver, built as a loadable module for the exact kernel the Snapmaker U1 runs.
The `tun-module` plugin places it on the printer and loads it, so `/dev/net/tun` exists for the VPN
plugins.

## What ships and where it comes from

The `.ko` is not stored in this repository. Bespok3d cross-builds it at build time from the upstream
source above, using the Docker toolchain in
[`tun-module/toolchain/`](../../tun-module/toolchain/): the `Dockerfile` fetches the kernel source at
the pinned commit and the ARM cross toolchain, and `junior-6.1.99.config` is the kernel
configuration the module is built against. The built module lands at
`tun-module/files/modules/tun-6.1.99.ko` in the package.

## Corresponding Source

Because Bespok3d builds this binary rather than shipping someone else's, Bespok3d owes the
Corresponding Source for it. That is the upstream commit named above plus the `Dockerfile` and the
`.config` in `tun-module/toolchain/`, which are in this repository and are published with every
release. The inventory entry is in
[`Bespok3d_history/doc/gpl-source-inventory.md`](../../../../Bespok3d_history/doc/gpl-source-inventory.md).

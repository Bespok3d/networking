# Attributions - tun-module

**Plugin author:** the Linux kernel contributors, built by Bespok3d from the printer kernel source

Loads the kernel `tun` driver the VPN plugins need.

| Upstream project | Author | Licence | Needed at runtime | Code ships in this package |
| --- | --- | --- | --- | --- |
| Linux kernel `tun` driver 6.1.99 | the Linux kernel contributors | GPL-2.0-only | yes | yes |

The module is cross-built at build time from the Rockchip kernel tree at commit
`8533b2249e1550b233a4836d039d64e3bb2fed7a`, against the stock Snapmaker U1 kernel configuration, and
shipped as a `.ko`. The licence text and the provenance note are in `vendor/linux-tun/` at the root
of this repository.

Because Bespok3d builds this binary, Bespok3d owes its Corresponding Source: the pinned upstream
commit plus the `Dockerfile` and `junior-6.1.99.config` in `tun-module/toolchain/`, both published
with every release. The inventory entry is in `Bespok3d_history/doc/gpl-source-inventory.md`.

Related Extended Firmware overlay: `10-patch-kernel-modules` (paxx12), GPL-3.0.

# Changelog

## 0.1.0

First release. Carries a `tun.ko` cross-built against the Snapmaker U1's exact kernel (Linux 6.1.99
aarch64, `vermagic 6.1.99 SMP preempt mod_unload aarch64`) and loads it at boot, giving the printer a
working `/dev/net/tun`. This is the base the ZeroTier and Tailscale plugins build their mesh network
on. Loads before the services that need it (`s05` before `s65`); unloads cleanly on uninstall; a
failed load deactivates the plugin so the printer is never left broken.

**The `.ko` is built from the kernel commit Snapmaker actually ships**
(`rockchip-linux/kernel` develop-6.1 @ `8533b224`), NOT the commit literally tagged "Linux 6.1.99"
(`cac15753`). Both report the same vermagic and both `insmod` cleanly, but they are six months of BSP
commits apart, so their net-stack structs differ, and with MODVERSIONS off there is no symbol-CRC to
catch it. An early build from the tagged commit loaded fine yet failed `TUNSETIFF` with EINVAL
(`register_netdevice` -> `ethtool_check_ops` WARN): it was non-functional despite loading. The correct
commit was identified from the community Extended Firmware's `vars.mk`, which runs Tailscale over
kernel tun on this exact board.

**Device-verified end-to-end on junior (2026-07-05), through the real daemon install path.** With the
module loaded, `ip tuntap add dev X mode tun` succeeds and creates a real interface (the strengthened
gate: "loads" and "node exists" are NOT proof, only creating an interface is). On top of it, the
`tailscale` plugin brought up a live `tailscale0` interface (`Engine created`, `UP,LOWER_UP`) and the
`zerotier` plugin brought up a live `zt*` interface (`UP,LOWER_UP`), both over this `.ko`, with no
kernel warnings. All three plugins uninstalled cleanly (module unloaded, symlinks removed, no orphaned
processes); Klipper and Moonraker stayed up throughout. One known cosmetic gap, not fixed here:
uninstall does not remove the `mknod`'d `/dev/net/tun` device node itself (only unloads the module), so
a stale, harmless (inert once the module is gone) node persists, worth a look whenever the kmodule
uninstall path (`daemon/core/packages/kmodules.py`) is next touched.

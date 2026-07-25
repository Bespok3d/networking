# TUN kernel module

Gives the printer a working `/dev/net/tun`. A mesh VPN builds a virtual network interface (a
"tunnel") on top of that device node: ZeroTier's `zerotier-one` needs it, and Tailscale runs lighter
over it than in its userspace fallback. Most Linux boxes ship `tun` already; the Snapmaker U1 does
not (its stock kernel has `# CONFIG_TUN is not set`, neither built in nor as a module), so this
plugin carries the module and loads it.

You rarely install this directly. A VPN plugin declares `require: tun`, so installing ZeroTier or
Tailscale pulls this in first. There is nothing to configure.

## What it does

- Places a cross-built `tun.ko` under the bespok3d modules dir (the `kernel-module` placement class).
- Loads it at boot through an `s05tun` init script the adapter renders: it `mknod`s
  `/dev/net/tun` (char 10:200) and `insmod`s the module BEFORE the `s65` services, so a VPN service
  that needs it finds it already loaded.
- On uninstall, unloads the module (`rmmod`) and removes the device node and the placement. A VPN
  plugin that depends on it is removed first, so the service releases the module before it unloads.
- If the load ever fails, the plugin deactivates itself (files kept, symlinks dropped) rather than
  leave the printer in a half-loaded state. The printer is never broken by this plugin.

## How the `.ko` is built (and why it is safe)

`tun.ko` is not a kernel rebuild. It is a single module cross-built against the U1's exact kernel
source point and config, so its `vermagic` matches what the running kernel's `insmod` accepts:

| Ingredient | Value |
| --- | --- |
| Kernel source | `rockchip-linux/kernel` @ `cac15753b8ce` (Linux 6.1.99, the RK3562 BSP) |
| Config | the U1's own `/proc/config.gz`, with `CONFIG_TUN=m` |
| Toolchain | ARM 10.3-2021.07 `aarch64-none-linux-gnu` (the compiler the stock kernel was built with) |
| vermagic | `6.1.99 SMP preempt mod_unload aarch64` |

Honest limit: the U1 kernel has `CONFIG_MODVERSIONS` off, so there is no per-symbol CRC safety net.
A `vermagic` string match is necessary but NOT sufficient. The module is trusted only after it
actually `insmod`s on the device and `/dev/net/tun` is exercised, never from the string alone. The
Docker cross-build (the `toolchain/` Dockerfile, run by b3-builder's bake step) checks the
`vermagic`; the device-verify is the real gate.

## Per-kernel variants

The `.ko` is selected by the `kernel_release` variant dimension (`when: { kernel_release: "6.1.99" }`).
A different kernel is a different `.ko`: adding a board means cross-building its module and adding a
variant. A printer whose kernel matches no variant places no module (it fails closed rather than
loading a mismatched `.ko`). A future OTA kernel bump is handled by the recover path re-selecting the
variant for the new kernel; that autofixer is planned for a later release.

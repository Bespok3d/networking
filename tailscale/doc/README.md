# Tailscale

Joins the printer to your [Tailscale](https://tailscale.com/) mesh network (tailnet), so
Fluidd/Mainsail, the camera, and SSH are reachable from anywhere without opening a port on your
router.

## Setup

1. Generate an auth key at [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys).
   A reusable key lets you reinstall this plugin later without generating a new one.
2. Install this plugin and paste the key into **Tailscale auth key**.
3. The printer appears in your tailnet's device list (the admin console, or `tailscale status` from
   any other device on the tailnet) once it has joined.
4. Reach the printer at its tailnet IP or MagicDNS name from anywhere your account is signed in.

Bring your own account: Bespok3d hosts no coordination service and never sees your auth key or
traffic.

## What it installs

- `tailscaled`, Tailscale's backend, run as a managed service against a real kernel `tailscale0`
  TUN interface.
- `tailscale`, Tailscale's CLI, used only by `ts-run` to join.
- `ts-run`, a small wrapper this plugin ships: it starts `tailscaled`, waits for its control
  socket, then runs `tailscale up --auth-key=...` once to join, then tracks `tailscaled` so the
  printer's service supervisor can stop it cleanly (and clean up its netfilter state on stop, the
  same step `tailscaled`'s own systemd unit runs via `ExecStopPost`).
- Requires the `tun-module` plugin (installed automatically): Tailscale runs over a real
  `/dev/net/tun`-backed interface here rather than its userspace-networking fallback, which is
  lighter on the printer and consistent with how the ZeroTier plugin uses the same base.

## Reaching Moonraker over Tailscale

**Known limitation.** The printer's `trusted_clients` list (`moonraker.conf`, `[authorization]`)
does not include Tailscale's `100.64.0.0/10` range, so a request arriving over the tailnet is not
automatically trusted the way a request from the local network is. This is not specific to this
plugin: Moonraker resolves a same-named config option from the LAST included file that sets it, so
a second `[authorization]` block from this plugin's own config would silently overwrite the base
list rather than add to it (confirmed against Moonraker's own `confighelper.py` include handling,
and already flagged in this project's own firmware-porting notes before this plugin existed). Making
`trusted_clients` genuinely additive needs a real daemon mechanism this package format does not
have yet (an instrument-style patch to the base `moonraker.conf`, not a plain config include); see
the project seed for the open architecture item.

Until that lands, reach Moonraker/Fluidd over Tailscale the same way any device outside your LAN
already does: log in with a Moonraker user or API key rather than relying on the trusted-IP bypass.
This does not block using the plugin, it only means the printer does not treat your tailnet as
implicitly trusted.

## Changing your auth key

**Known gap, expected but not yet independently confirmed on hardware for this plugin.** The
ZeroTier plugin in this same co-repo confirmed on real hardware that changing a `requires.variables`
value (like its `ZT_NETWORK_ID`) and reconfiguring does not actually take effect: the daemon's
reconfigure only re-renders template placements and restarts services, it does not regenerate an
`install.service` entry's `command`/`args` from the new value. Since this plugin's `TS_AUTHKEY` is
used the same way, the same gap is expected to apply here. To change the auth key today: uninstall
the plugin and reinstall it with the new key.

## Uninstalling

Uninstalling stops the service (running `tailscaled --cleanup` first, the same as a normal `stop`)
and removes the plugin's files. The printer's Tailscale node identity (`tailscaled.state` under the
plugin's data directory) is left in place, so reinstalling keeps the same tailnet device instead of
registering a new one. If you want a clean identity, delete `$BESPOK3D/var/lib/tailscale` after
uninstalling, or remove the device from your tailnet's admin console.

## Known limitation: does not currently start on the U1 (confirmed on real hardware)

`tailscaled` and `tailscale` here are Tailscale's own official static Linux binaries for arm64
(SHA-pinned download from `pkgs.tailscale.com`, not compiled by this plugin), statically linked
with no glibc dependency at all, so unlike the ZeroTier plugin there is no glibc-compatibility
question. However, device-verify on real hardware found a genuine blocker: `tailscaled` fails to
create its `tailscale0` kernel TUN interface (`tstun.New("tailscale0"): invalid argument`) even
though `tun-module` loaded successfully and `/dev/net/tun` exists with the right permissions. The
kernel logs a `WARNING: ... at net/ethtool/common.c:534 ethtool_check_ops+0x18/0x30` at the exact
moment of the failing `TUNSETIFF` ioctl, reproduced twice independently (once by `tailscaled`
itself, once by a raw Python ioctl call against the same device node), so this is a real kernel/
module interaction, not a `tailscaled` bug. `tailscaled --tun=userspace-networking` (no kernel TUN
at all) was confirmed working on the same hardware in the same session, so a userspace-networking
fallback is a real, available option if the kernel-tun path is not fixed. See the project seed for
the full diagnostic account; this is flagged forward as a kernel-module-class investigation, not
something this plugin's own code can fix.

This plugin's own code (the `ts-run` join wrapper, the manifest, the arch-variant placements) is
otherwise install/uninstall clean per the same device-verify: install, uninstall, and the printer
staying usable throughout all worked correctly. See the plugin's CHANGELOG for the full status.

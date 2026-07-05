# Tailscale

Joins the printer to your [Tailscale](https://tailscale.com/) mesh network (tailnet), so
Fluidd/Mainsail, the camera, and SSH are reachable from anywhere without opening a port on your
router.

## Setup

1. Get an auth key from the Tailscale admin console:
   [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys) then
   **Generate auth key**.

   **If you just created your Tailscale account, watch for the onboarding trap.** A brand-new account
   does not land on the keys page: Tailscale's setup wizard takes you to a "Add a second device" /
   "Connect a device" screen that sits and waits for a device to join, and even "Skip this
   introduction" drops you on the dashboard, not the keys page. There is no key on either screen. To
   get past it: finish or skip the wizard, then open the keys page directly with the link above (or in
   the admin console go **Settings -> Keys -> Generate auth key**). Do not wait on the "add a device"
   screen; the printer will appear there on its own once it joins with the key.

   Turn on **Reusable** when generating the key. A reusable key lets you reinstall this plugin later
   without generating a new one, AND it can be used on more than one printer: every device that joins
   with it appears in your tailnet as its own machine, so one reusable key covers your whole fleet. A
   non-reusable (one-off) key works for a single join only.
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

Fluidd/Mainsail load over the tailnet without a login prompt: this plugin trusts Tailscale's
`100.64.0.0/10` range (RFC 6598 CGNAT), which Moonraker's stock `trusted_clients` list does not
include, so a request over the tailnet is treated as trusted the same way a LAN request is.

It works by dropping a small `.cfg` into the printer's `bespok3d/moonraker/` include directory that
re-declares `[authorization] trusted_clients` with the stock list PLUS `100.64.0.0/10`. Moonraker
merges included config per option and the last definition wins, so this replaces only the
`trusted_clients` list (the stock `cors_domains` and any other setting are left as they are) and adds
your tailnet range to it. Uninstalling this plugin removes the file and restores the stock trusted
list. Moonraker is restarted once on install so the change takes effect.

If you prefer not to trust the tailnet range implicitly, you can still log in with a Moonraker user
or API key instead; that path keeps working regardless.

## Changing your auth key

Edit the auth key in the Config tab and apply it: no reinstall needed. The daemon re-renders this
plugin's `authkey` file from the new `TS_AUTHKEY` and restarts the service, and `ts-run` reads the
key from that file on every start (it is not baked into the init script as a fixed argument), so the
next start runs `tailscale up` with the new key. A reusable key change takes effect without touching
the printer's tailnet identity (the node keeps its place in your tailnet).

## Uninstalling

Uninstalling stops the service (running `tailscaled --cleanup` first, the same as a normal `stop`)
and removes the plugin's files. The printer's Tailscale node identity (`tailscaled.state` under the
plugin's data directory) is left in place, so reinstalling keeps the same tailnet device instead of
registering a new one. If you want a clean identity, delete `$BESPOK3D/var/lib/tailscale` after
uninstalling, or remove the device from your tailnet's admin console.

## Binaries and the kernel-TUN path

`tailscaled` and `tailscale` here are Tailscale's own official static Linux binaries for arm64
(SHA-pinned download from `pkgs.tailscale.com`, not compiled by this plugin), statically linked with
no glibc dependency at all, so unlike the ZeroTier plugin there is no glibc-compatibility question.

Tailscale runs over the kernel `tailscale0` TUN interface backed by `tun-module`'s `/dev/net/tun`,
confirmed end to end on real hardware: the interface comes up with a tailnet (`100.64.0.0/10`) IP and
the printer joins the tailnet as `bespok3d-printer`. An earlier device-verify hit a `TUNSETIFF`
failure that traced to a wrong-commit `tun.ko` (vermagic matched but the module was still broken);
that was fixed in the `tun-module` base, not here. If the kernel-TUN path is ever unavailable on a
given board, `tailscaled` also supports `--tun=userspace-networking` as a fallback.

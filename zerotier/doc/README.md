# ZeroTier

Joins the printer to a [ZeroTier](https://www.zerotier.com/) mesh network, so Fluidd/Mainsail, the
camera, and SSH are reachable from anywhere without opening a port on your router.

## Setup

1. Create a free network at [my.zerotier.com](https://my.zerotier.com/) (or use an existing one) and
   copy its 16 hex digit network id.
2. Install this plugin and paste the network id into **ZeroTier network id**.
3. In ZeroTier Central, find the printer in the network's member list and check **Auth** to
   authorize it, exactly like authorizing a new laptop or phone.
4. Once authorized, the printer gets an address on the network. `zerotier-one -q listnetworks`
   over SSH shows it once assigned.

Bring your own account: Bespok3d hosts no coordination service and never sees your network id or
traffic.

## What it installs

- `zerotier-one`, ZeroTier's own binary, run as a managed service.
- `zt-run`, a small wrapper this plugin ships: it pre-authorizes the network id you configured (the
  documented `networks.d/<network-id>.conf` marker ZeroTier itself reads on startup, not a scripted
  `zerotier-cli join`) and then runs `zerotier-one` in the foreground so the printer's service
  supervisor can track it directly.
- Requires the `tun-module` plugin (installed automatically): ZeroTier needs a real
  `/dev/net/tun`, which the stock Snapmaker U1 kernel does not ship without it.

## Changing networks

Edit the network id in the Config tab and apply it: the plugin switches networks in place, no
reinstall needed. The daemon re-renders this plugin's `network-id` file from the new `ZT_NETWORK_ID`
and restarts the service, and `zt-run` reads the id from that file on every start (it is not baked
into the init script as a fixed argument). On the next start it removes only the join marker it
previously created and joins the new network, leaving any network you joined by hand over SSH
untouched.

Remember to authorize the printer in ZeroTier Central for the new network, the same as the first
join.

## Reaching Moonraker over ZeroTier

ZeroTier's default managed-route pool (in `10.0.0.0/8`, `172.16.0.0/12`, or `192.0.0.0/8`) already
falls inside Moonraker's stock `trusted_clients` list, so Fluidd/Mainsail load over ZeroTier without
a login prompt out of the box. If you configure your ZeroTier network with a custom managed range
OUTSIDE those blocks (for example a CGNAT `100.64.0.0/10` range), Moonraker will ask that range to
log in. To trust it, add your range to `[authorization] trusted_clients` in `moonraker.conf` (keep
every existing entry and add yours), or simply log in with a Moonraker user. The Tailscale plugin
ships a ready-made trusted-range file because its range is a fixed known value; ZeroTier's is set per
network in your account, so it cannot be shipped ahead of time.

## Uninstalling

Uninstalling stops the service and removes the plugin's files. The printer's ZeroTier identity
(`identity.secret` under the plugin's data directory) is left in place, so reinstalling keeps the
same ZeroTier address instead of generating a new one. If you want a clean identity, delete
`$BESPOK3D/var/lib/zerotier` after uninstalling.

## Known limitation (flag before relying on this in production)

`zerotier-one` here is the official ZeroTier binary extracted from their Debian arm64 package
(SHA-pinned download, not compiled by this plugin); it is dynamically linked against glibc. The
Snapmaker U1's own kernel and camera toolchain both target `aarch64-none-linux-gnu` (glibc, not
musl), which is a good sign, but this plugin has **not yet been confirmed to run on a real printer**
(no static ZeroTier build exists upstream to sidestep this entirely). If the printer's glibc is
older than the one this binary was built against, it will fail to start with a `GLIBC_x.xx not
found` error, not silently misbehave. See the plugin's CHANGELOG for the device-verify status.

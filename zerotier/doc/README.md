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

**Known gap, confirmed on real hardware:** editing the network id in the Config tab and applying it
does NOT currently switch networks. The daemon's reconfigure only re-renders `render: true` template
placements and restarts services; it does not regenerate an `install.service` entry's `command`/
`args` from the new value, so the already-installed service keeps execing with the network id that
was baked in at install time. `zt-run`'s own switch logic (removing only the marker it previously
created, joining the new one) is correct and unit-tested, but nothing currently re-invokes it with a
new value after install. To actually change networks today: uninstall the plugin and reinstall it
with the new `ZT_NETWORK_ID`. This is a daemon-mechanism limitation, not specific to this plugin -
see the project seed for the wider note (likely affects any plugin whose `install.service` args
reference a `requires.variables` value).

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

# Changelog

## 0.1.2 (2026-08-16)

ZeroTier is now a stable plugin. Before, it only showed up in the store if you had set your plugin
channel to testing; now it shows for everyone. Nothing about the plugin itself changed.

## 0.1.1 (2026-07-05)

You can now change the ZeroTier network from the Config tab without reinstalling. The network id is
read from a rendered file on every start instead of being fixed at install time, so applying a new
`ZT_NETWORK_ID` switches networks on the next restart (removing only the join marker this plugin
created, and leaving any network you joined by hand over SSH alone). Remember to authorize the
printer for the new network in ZeroTier Central.

Docs: added a note on reaching Moonraker over ZeroTier. The default managed-route pool already falls
inside Moonraker's stock trusted list, so Fluidd loads without a login prompt out of the box; a
custom range outside those blocks needs a manual `trusted_clients` addition (documented).

## 0.1.0 (2026-07-05)

Initial release. `zerotier-one` (upstream 1.16.2, official Debian arm64 package, SHA-pinned) as a
managed service on top of `tun-module`; `zt-run` wrapper pre-authorizes the configured
`ZT_NETWORK_ID` via the documented `networks.d` marker file.

**Device-verified on junior (2026-07-05):** installed through the real daemon API after updating it
to 0.12.15-dev; `zerotier-one` (dynamically linked against glibc) runs natively on the U1's own
userspace (glibc 2.38, no compatibility issue found); `/dev/net/tun` present after `tun-module`
loaded; the service joined a fake test network id and reported `ONLINE` with a real ZeroTier
address; Klipper and Moonraker stayed up throughout; uninstall left the printer clean. Found and
documented one real gap during this pass: reconfiguring the plugin's `ZT_NETWORK_ID` after install
does not actually switch networks (see `doc/README.md`, "Changing networks") - a daemon-mechanism
limitation, not something this release can fix on its own.

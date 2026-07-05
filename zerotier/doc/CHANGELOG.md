# Changelog

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

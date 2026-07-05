# Changelog

## 0.1.0 (2026-07-05)

Initial release. `tailscaled` + `tailscale` (upstream 1.98.8, official static arm64 build,
SHA-pinned) as a managed service on top of `tun-module`; `ts-run` wrapper starts `tailscaled` over
a real kernel `tailscale0` interface and joins the tailnet with the configured `TS_AUTHKEY`.

**Device-verified install/uninstall on junior (2026-07-05), join blocked by a real kernel finding.**
Installed through the real daemon API (`tun-module` then `tailscale`, since fresh-install `require`
enforcement is not yet automatic; see the daemon-mechanism gap the ZeroTier plugin already logged).
`tailscaled` failed to bring up its `tailscale0` kernel TUN interface
(`tstun.New("tailscale0"): invalid argument`), reproduced twice with a kernel
`WARNING: ... at net/ethtool/common.c:534 ethtool_check_ops+0x18/0x30` at the moment of the
failing `TUNSETIFF` ioctl, even though `tun-module` loaded `tun.ko` cleanly and `/dev/net/tun`
existed with correct permissions. `tailscaled --tun=userspace-networking` was confirmed working on
the same hardware in the same session, so a userspace fallback is real and available. `ts-run`'s
own bounded readiness wait and cleanup handling worked correctly under this failure: no orphaned
processes, the service ended in a clean `stopped` state, and Klipper/Moonraker were never
interrupted. Uninstall (`tailscale` then `tun-module`) left the printer in its original clean
state. Channel stays `experiment`: this is NOT a passing device-verify, it is a real, reproduced
blocker on the kernel-tun path. See the project seed for the full diagnostic account and the
handoff to further investigation.

# Attributions - tailscale

**Plugin author:** Tailscale Inc., packaged by Bespok3d; the idea of a VPN on the U1 comes from the Extended Firmware overlay `66-app-vpn`, initial Tailscale support there by @mcristina422

Puts the printer on a Tailscale network.

| Upstream project | Author | Licence | Needed at runtime | Code ships in this package |
| --- | --- | --- | --- | --- |
| Tailscale client | Tailscale Inc. | BSD-3-Clause | yes | yes |

The official arm64 Tailscale build (currently 1.98.8) is downloaded from https://pkgs.tailscale.com
at build time and shipped inside the package.

The binaries are Tailscale's own builds, shipped byte for byte as downloaded; nothing of
Tailscale's is stored in this repository. The licence text and the provenance note are in
`vendor/tailscale/` at the root of this repository.

Ported from the Extended Firmware overlay `66-app-vpn`, GPL-3.0, whose Tailscale work is credited to
@mcristina422.

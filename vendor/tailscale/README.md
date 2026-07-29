# Tailscale

A separate work, aggregated with this repository. Not covered by this repository's licence.

| | |
| --- | --- |
| Upstream | <https://github.com/tailscale/tailscale> |
| Copyright | Tailscale Inc and contributors |
| Version shipped | 1.98.8 |
| Licence text retrieved | 2026-07-28, from tag `v1.98.8` |
| Licence | BSD-3-Clause, in [LICENSE](LICENSE) |

## What it is

The Tailscale client: the `tailscaled` daemon and the `tailscale` command. The `tailscale` plugin
runs the daemon as a managed service so the printer joins a tailnet.

## What ships and where it comes from

Nothing of Tailscale's is stored in this repository. The `tailscale` plugin's manifest carries a bake
directive that downloads the official arm64 release tarball at build time, pinned by URL and sha256,
and places two binaries from it in the built package:

```text
url     https://pkgs.tailscale.com/stable/tailscale_1.98.8_arm64.tgz
sha256  53eb3ce89d062fd34e393d24a6c8ec08c769fede8eb77fe9c6e347ad4ae00f84
members tailscale_1.98.8_arm64/tailscaled  ->  files/bin/tailscaled-aarch64
        tailscale_1.98.8_arm64/tailscale   ->  files/bin/tailscale-aarch64
```

The binaries are Tailscale's own builds and are shipped byte for byte as downloaded. Bespok3d
modifies nothing in them.

# ZeroTier One

A separate work, aggregated with this repository. Not covered by this repository's licence.

| | |
| --- | --- |
| Upstream | <https://github.com/zerotier/ZeroTierOne> |
| Copyright | ZeroTier, Inc. |
| Version shipped | 1.16.2 |
| Licence texts retrieved | 2026-07-28, from tag `1.16.2` |
| Licence of the agent | MPL-2.0, in [LICENSE-MPL.txt](LICENSE-MPL.txt) |
| Licence of the controller parts | ZeroTier SOURCE-AVAILABLE LICENSE Version 1.0, no SPDX identifier, in [LICENSE-SOURCE-AVAILABLE.md](LICENSE-SOURCE-AVAILABLE.md) |

## What it is

The ZeroTier One service daemon. The `zerotier` plugin runs it as a managed service so the printer
joins a ZeroTier network.

## What ships and where it comes from

Nothing of ZeroTier's is stored in this repository. The `zerotier` plugin's manifest carries a bake
directive that downloads the official arm64 Debian package from ZeroTier at build time, pinned by
URL and sha256, and places the `zerotier-one` binary from it in the built package:

```text
url     https://download.zerotier.com/RELEASES/1.16.2/dist/debian/bookworm/zerotier-one_1.16.2_arm64.deb
sha256  f301d9dac63fad57e8efe90d1221e740ece7e2c70ebda1684915fd7cb00cdc54
member  usr/sbin/zerotier-one  ->  files/bin/zerotier-one-aarch64
```

The binary is ZeroTier's own build and is shipped byte for byte as downloaded. Bespok3d modifies
nothing in it.

## Use limitation

ZeroTier's own notice states the software is source-available and is not open source as defined by
the Open Source Initiative, that the agent is under MPL-2.0, that the controller and related parts
are under the Source-Available Licence above, and that commercial use as defined in that licence
requires a paid commercial licence from ZeroTier, Inc.

Both texts are reproduced here verbatim. The upstream map file that points at them is in
[LICENSE.txt](LICENSE.txt).

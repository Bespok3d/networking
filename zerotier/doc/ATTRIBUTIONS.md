# Attributions - zerotier

**Plugin author:** ZeroTier, Inc., packaged by Bespok3d

Puts the printer on a ZeroTier network.

| Upstream project | Author | Licence | Needed at runtime | Code ships in this package |
| --- | --- | --- | --- | --- |
| ZeroTier One 1.16.2, agent | ZeroTier, Inc. | MPL-2.0 | yes | yes |
| ZeroTier One 1.16.2, controller and related parts | ZeroTier, Inc. | ZeroTier SOURCE-AVAILABLE LICENSE Version 1.0, no SPDX identifier | yes | yes |

The official arm64 ZeroTier build (1.16.2) is downloaded from https://download.zerotier.com at build
time, pinned by URL and sha256, and shipped inside the package byte for byte as downloaded. Nothing
of ZeroTier's is stored in this repository and Bespok3d modifies nothing in it.

ZeroTier's own notice states the software is source-available and is not open source as defined by
the Open Source Initiative, and that commercial use as its licence defines it requires a paid licence
from ZeroTier, Inc. Both licence texts are reproduced verbatim in `vendor/zerotier-one/` at the root
of this repository, with the provenance note.

Related Extended Firmware overlay: `66-app-vpn`, GPL-3.0.

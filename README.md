# networking

[![licence](https://img.shields.io/badge/licence-AGPL--3.0-blue)](LICENSE)
[![release](https://img.shields.io/github/v/release/Bespok3d/networking)](https://github.com/Bespok3d/networking/releases)
![printer](https://img.shields.io/badge/printer-Snapmaker%20U1-informational)
![stock firmware](https://img.shields.io/badge/stock%20firmware-no%20flashing-brightgreen)

The Bespok3d networking co-repo: mesh-VPN plugins and the kernel base they build on.

| Plugin | What it is |
| --- | --- |
| `tun-module` | Carries a cross-built `tun.ko` and loads it, so the printer has a working `/dev/net/tun`. The base a mesh VPN needs. See `tun-module/doc/README.md`. |
| `zerotier` | Runs ZeroTier's `zerotier-one` as a managed service and joins a user-supplied network id. Requires `tun-module`. See `zerotier/doc/README.md`. |
| `tailscale` | Runs Tailscale's `tailscaled` as a managed service and joins a user-supplied tailnet with an auth key. Requires `tun-module`. See `tailscale/doc/README.md`. |

## Layout

```text
networking/
  <plugin-id>/          # one plugin = one dir; its name is the manifest .name
    manifest.json       # metadata + any bake directive (download / docker cross-build)
    toolchain/           # tun-module only: the Docker cross-build for tun.ko
    files/               # payload the daemon places on the printer
    doc/README.md        # rendered in-app; not deployed
  .github/workflows/release.yml
  dist/                 # build output (gitignored)
```

Each plugin declares WHAT (a destination `class` + a `service`/`kmodule` section), never a path or a
raw command; the printer-side adapter realizes it.

## Building

Builds run through the shared `Bespok3d/b3-builder` tool; `--bake` performs each plugin's declared
bake step (from its manifest) before packing:

- `tun-module` cross-builds `tun.ko` in Docker against the U1's exact kernel (the `toolchain/`
  Dockerfile) and stages the resulting `.ko`. The build validates the module's `vermagic`; the real
  gate is an on-device `insmod` on a printer.
- `zerotier` downloads ZeroTier's official arm64 release (SHA-pinned) and extracts the `zerotier-one`
  binary; nothing is compiled.
- `tailscale` downloads Tailscale's official static arm64 tarball (SHA-pinned) and extracts the
  `tailscaled` and `tailscale` binaries; nothing is compiled.

```sh
npm install github:Bespok3d/b3-builder
npx b3-builder build --source ./tun-module --atom-repo Bespok3d/networking --bake
# -> dist/tun-module-<version>.b3 + dist/tun-module.atom.json
```

## Releasing

Bump a plugin's `manifest.json` `version` and push the tag `plugin-<name>-v<version>` naming that
plugin and that exact number. A push to `main` publishes nothing, and the run is refused if the tag
and the manifest disagree. CI runs the `Bespok3d/b3-builder` Action, which bakes and packs each
plugin's `.b3` and cuts a release per plugin; the `register-atoms` action from `Bespok3d/main-index`
then registers the atoms. This repo contributes atoms only and publishes no list of its own.
Secrets: `MAIN_INDEX_TOKEN` (contents:write on main-index) and `REGISTRY_SIGNING_KEY` (the org
registry key the `b3-builder` Action signs each `.b3` and atom with).

## Composition

Bespok3d's own code in this repository is under the repository licence below. The contents of
[`vendor/`](vendor/) are separate works, each under its own licence, aggregated with Bespok3d's code
on the same distribution medium. They are not under the repository licence and Bespok3d does not
relicense them.

None of the third-party payload is stored in this repository. Each plugin's `manifest.json` carries a
bake directive that fetches or builds it at build time, so the third-party code enters only the built
`.b3` package. `vendor/<component>/` carries that component's own licence text verbatim and a
provenance note saying where it comes from, at which version, and how it is obtained.

| Component | What it is | Licence | Provenance |
| --- | --- | --- | --- |
| ZeroTier One 1.16.2 | the `zerotier` plugin's service daemon | MPL-2.0 for the agent, ZeroTier SOURCE-AVAILABLE LICENSE Version 1.0 for the controller parts | [`vendor/zerotier-one/`](vendor/zerotier-one/) |
| Tailscale 1.98.8 | the `tailscale` plugin's daemon and command | BSD-3-Clause | [`vendor/tailscale/`](vendor/tailscale/) |
| Linux `tun` driver 6.1.99 | the module `tun-module` loads | GPL-2.0-only | [`vendor/linux-tun/`](vendor/linux-tun/) |

ZeroTier's own notice states that its software is source-available and is not open source as defined
by the Open Source Initiative, and that commercial use as its licence defines it requires a paid
licence from ZeroTier, Inc. Anyone redistributing the built `zerotier` package is subject to that.

### Corresponding Source

The `tun-module` plugin ships `tun-6.1.99.ko`, the Linux `tun` driver, licensed GPL-2.0-only. Bespok3d
builds that module rather than fetching it, so the source that corresponds to the shipped binary is
upstream's source **plus** the configuration Bespok3d built it with:

- upstream: `https://github.com/rockchip-linux/kernel.git` at commit
  `8533b2249e1550b233a4836d039d64e3bb2fed7a`, kernel release 6.1.99
- Bespok3d's build: [`tun-module/toolchain/`](tun-module/toolchain/) in this repository, which holds
  the Dockerfile, the pinned cross toolchain and the kernel config the module is built against

Both are public and are in every release of this repository. Anyone who received the binary may take
that source and rebuild it. If any part of it is unreachable, ask the Bespok3d org and it will be
provided. The full inventory of every binary Bespok3d ships, with versions and checksums, is in
`Bespok3d_history/doc/gpl-source-inventory.md`.

Tailscale and ZeroTier are shipped as their projects publish them, so the source corresponding to
those binaries is upstream's own at the versions named above.

## Licence

Copyright (C) 2026 unlucio and the Bespok3d contributors

This program is free software: you can redistribute it and/or modify it under the terms of the GNU
Affero General Public License as published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If
not, see <https://www.gnu.org/licenses/>. The full text is in [LICENSE](LICENSE).

This licence covers Bespok3d's own code. It does not cover the separate works in `vendor/`, which
keep their own licences as listed under Composition.

Bespok3d is a project of the Bespok3d Organisation, which is not a legal entity. Copyright is held by
the individual authors named above.

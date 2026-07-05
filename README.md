# networking

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
    manifest.json
    build.sh            # only if the payload is a build output (cross-build or pinned download)
    toolchain/           # tun-module only: the Docker cross-build for tun.ko
    files/               # payload the daemon places on the printer
    doc/README.md        # rendered in-app; not deployed
  scripts/{pack.sh,generate-atom.mjs,assemble-list.mjs}
  .github/workflows/release.yml
  index.json            # the published sub-list (committed; referenced by main-index lists[])
  dist/                 # build output (gitignored)
```

Each plugin declares WHAT (a destination `class` + a `service`/`kmodule` section), never a path or a
raw command; the printer-side adapter realizes it. See `Bespok3d/doc/package-format.md`.

## Building

A plugin whose payload is a build output ships its own `build.sh` at its root (the co-repo's CI and
`scripts/pack.sh` never build anything themselves, they only stage what is already on disk):

- `tun-module/build.sh` runs the Docker cross-build (`tun-module/toolchain/build.sh`) against the
  U1's exact kernel and stages the resulting `.ko`. The build validates the module's `vermagic`; the
  real gate is an on-device `insmod` on a printer.
- `zerotier/build.sh` downloads ZeroTier's official arm64 release (SHA-pinned) and extracts the
  `zerotier-one` binary; nothing is compiled.
- `tailscale/build.sh` downloads Tailscale's official static arm64 tarball (SHA-pinned) and
  extracts the `tailscaled` and `tailscale` binaries; nothing is compiled.

Run a plugin's `build.sh` locally, then `scripts/pack.sh` to produce `dist/<name>-<version>.b3`.

## Releasing

Bump a plugin's `manifest.json` `version` and push to `main`. CI builds each plugin's payload, packs
each `.b3`, cuts a release per plugin, regenerates this repo's `index.json` sub-list, and registers
it in `Bespok3d/main-index`. Secret: `MAIN_INDEX_TOKEN` (contents:write on main-index). Signing
deferred.

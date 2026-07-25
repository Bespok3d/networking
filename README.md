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

Bump a plugin's `manifest.json` `version` and push to `main`. CI runs the `Bespok3d/b3-builder`
Action, which bakes and packs each plugin's `.b3` and cuts a release per plugin; the `register-atoms`
action from `Bespok3d/main-index` then registers the atoms. This repo contributes atoms only and
publishes no list of its own. Secrets: `MAIN_INDEX_TOKEN` (contents:write on main-index) and
`REGISTRY_SIGNING_KEY` (the org registry key the `b3-builder` Action signs each `.b3` and atom with).

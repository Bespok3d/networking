# Packet 1 recon: kernel-path classification + build-machinery inventory

Read-only recon for the VPN/kernel-module relay
(`~/.claude/plans/ok-we-have-to-eventual-wren.md`). No device mutation performed. Probes run
2026-07-04 on junior (root@10.6.9.109, password auth, read-only SSH).

> NOTE (2026-07-04, Opus recheck): an earlier Sonnet draft of this doc classified the tun path as
> BLOCKED. That was WRONG. It is corrected below to MODULE-BUILDABLE. The three errors it made are
> called out inline so the mistake is not repeated: (1) it read `/proc/config.gz` and then claimed we
> lack the `.config` we in fact hold byte-for-byte; (2) it missed `CONFIG_MODULE_FORCE_LOAD=y`; (3) it
> treated "not in Snapmaker's GitHub org" as "no GPL source", when the source is the public Rockchip
> BSP (`rockchip-linux/kernel` develop-6.1) that carries this exact reference-board DTS.

## A. Kernel-path classification: MODULE-BUILDABLE (high confidence, verify by on-device insmod)

### Raw findings on junior

| Check | Result |
| --- | --- |
| `cat /proc/misc \| grep tun` | empty (no tun misc device registered) |
| `ls -l /dev/net/tun` | does not exist |
| `zcat /proc/config.gz \| grep CONFIG_TUN` | `# CONFIG_TUN is not set` (not built-in, not a module) |
| `CONFIG_IKCONFIG_PROC` | `=y`, so `/proc/config.gz` IS the exact running kernel config (7835 lines, complete). We already hold it; saved to scratchpad `junior-running.config`. |
| `CONFIG_MODVERSIONS` | not set (OFF): no per-symbol CRC checking, so NO `Module.symvers` needed |
| `CONFIG_MODULE_SIG` | not set: no signature enforcement |
| `CONFIG_MODULE_FORCE_LOAD` | `=y`: `insmod --force` can bypass a vermagic mismatch entirely |
| `CONFIG_MODULE_COMPRESS_NONE` | set (plain uncompressed `.ko`) |
| `CONFIG_SMP` / `CONFIG_PREEMPT` (not `_RT`) / `CONFIG_MODULE_UNLOAD` | all `=y` (these + version determine vermagic) |
| `CONFIG_LOCALVERSION` / `CONFIG_LOCALVERSION_AUTO` | `""` / `=y` (but `uname -r` is plain `6.1.99`, see vermagic note) |
| device-tree `compatible` | `rockchip,rk3562-evb2-ddr4-v10` then `rockchip,rk3562`: the STOCK Rockchip EVB2 reference board |
| `uname -r` | `6.1.99` exactly (no localversion suffix) |
| vermagic of stock `.ko` (`io_manager.ko`/`bcmdhd.ko`, via `strings`; no `modinfo` binary on box) | `6.1.99 SMP preempt mod_unload aarch64` |
| kernel build string | `Linux version 6.1.99 (snapmaker@build-srv) (aarch64-none-linux-gnu-gcc ... 10.3.1 20210621 (ARM GNU Toolchain 10.3-2021.07) ...) #1 SMP PREEMPT Fri Jul 3 12:22:00 CST 2026` |
| `.ko` files present on the box | `/usr/lib/modules/{bcmdhd,chsc6540,io_manager,8733bs}.ko`; `8733bs.ko` ships but is NOT loaded (absent from `lsmod`) |
| insmod/modprobe/rmmod | present (busybox at `/sbin/`, real at `/usr/sbin/`) |

### Why this is buildable, not blocked

**It is a stock Rockchip BSP kernel, not a Snapmaker-authored one.** The device-tree `compatible`
string is `rockchip,rk3562-evb2-ddr4-v10`, Rockchip's own EVB2 evaluation board. That exact DTS
(`arch/arm64/boot/dts/rockchip/rk3562-evb2-ddr4-v10.dts`) is present RIGHT NOW in the public GPL
`rockchip-linux/kernel` tree on the `develop-6.1` branch (verified via the GitHub API this session).
Snapmaker took the RK3562 6.1 BSP, used the reference-board device tree essentially as-is, and layered
Klipper/Moonraker/Fluidd on top. So the "we lack GPL kernel source" premise is false: the source is the
Rockchip BSP, which is public.

**We already have the exact `.config`.** `CONFIG_IKCONFIG_PROC=y` means `/proc/config.gz` is the running
kernel's own config. We do not need Snapmaker to publish it; it is on the device and copied to
scratchpad. This is the single artifact the earlier draft claimed we were missing while it was reading
that very file.

**MODVERSIONS is OFF, so no `Module.symvers` is required.** With no per-symbol CRC, the only string-level
gate `insmod` applies is the vermagic exact-match, and we control every token of it (below).

**`CONFIG_MODULE_FORCE_LOAD=y` is a second escape hatch.** Even if the vermagic did not match, a forced
load is permitted. We prefer a clean vermagic match, but the box is configured to allow forcing past a
mismatch.

**vermagic (`6.1.99 SMP preempt mod_unload aarch64`) is fully reproducible.** Every token comes from
options we hold: version 6.1.99 (Makefile version + suppress localversion so `UTS_RELEASE` stays plain
`6.1.99`, since `LOCALVERSION_AUTO=y` would otherwise append a git suffix that junior does NOT have),
`SMP` (`CONFIG_SMP=y`), `preempt` (`CONFIG_PREEMPT=y`, not `_RT`), `mod_unload` (`CONFIG_MODULE_UNLOAD=y`),
`aarch64` (arch). All present in junior's `.config`.

**Toolchain is public.** Built with ARM's published `aarch64-none-linux-gnu-gcc` 10.3-2021.07. Compiler
version is not part of vermagic and (MODVERSIONS off, no CRC) not load-fatal if it differs; we can match
it exactly to minimize any risk.

### Classification

**MODULE-BUILDABLE (high confidence). Verify by on-device insmod, never by string.**

- Build path: `rockchip-linux/kernel` @ `develop-6.1` (board `rk3562-evb2-ddr4-v10`) + junior's exact
  `.config` + flip `CONFIG_TUN=m` + suppress localversion so `UTS_RELEASE` == `6.1.99` + ARM 10.3-2021.07
  toolchain, Docker/QEMU-arm64 like the `u1-hw-camera` model. Build `drivers/net/tun.ko`, scp to junior,
  `insmod`, confirm `/dev/net/tun` appears (tun self-registers a misc node) and an interface can be
  created; `rmmod` cleanly.
- The one honest caveat: MODVERSIONS-off means there is NO CRC safety net, so a struct-layout mismatch
  (if the public BSP source differs from Snapmaker's in a core header) would fail SILENTLY rather than be
  rejected at load. Risk is low (we use their exact `.config`, so config-driven struct sizes match; a
  printer vendor patching core net structs is unlikely) but nonzero. Mitigation is exactly the acceptance
  gate the plan already specifies: attempt `insmod` on junior and classify the actual result, plus
  exercise the device (open `/dev/net/tun`, bring up an interface) before trusting it. This is normal
  device-verify, NOT a blocker.
- De-risk option if the first source point does not load cleanly: build the `.ko` against a couple of
  candidate source points (nearest RK BSP commit variants) and try each on junior; the one that
  `insmod`s and exercises cleanly wins. This is the same variant-selection mechanism the relay is
  building anyway.

### Effect on the packets

- **Packet 4 (cross-build `tun.ko`, the forcing case) proceeds as originally scoped.** It is the real
  hardest-artifact validator and it is available. ZeroTier's `/dev/net/tun` dependency is satisfiable.
- **Packet 6 (ZeroTier plugin) is UNBLOCKED.**
- **Packet 3 (kernel-module mechanism)**: `tun.ko` is the intended specimen. As a bonus, the
  already-shipped-but-unloaded `/usr/lib/modules/8733bs.ko` (RTL8733BS Wi-Fi driver, matching vermagic)
  is a zero-cross-build smoke test of the load/unload/autostart mechanics before the `tun.ko` build
  lands, if useful during packet 3 bring-up. It is a convenience, not a required fallback.
- **Packet 7 (Tailscale, userspace) is unaffected** either way and remains the non-kernel arch-variant
  validation path.

## B. Build-machinery inventory

All paths read, none modified. "Bakes" = CI-time artifact production; the printer never compiles or
pips anything at runtime (ADR-0036 discipline extends to every artifact class below).

| Path | Artifact class | How it targets aarch64 | How the packer enforces baking |
| --- | --- | --- | --- |
| `plugins/octoeverywhere-plugin/octoeverywhere/build.sh` | Vendored Python app source (git tag fetch, no compile) + Python wheels | `pip download --platform manylinux2014_aarch64 --platform manylinux_2_17_aarch64 --platform manylinux_2_28_aarch64 --python-version 311 --abi cp311`, cross-download only, no compile | `Bespok3d/scripts/pack-plugins.sh` `ensure_baked` detects the plugin's own `build.sh` (a "complete idempotent baker") and defers to it over the generic `bake-deps.sh` path |
| `plugins/octoeverywhere-plugin/scripts/bake-deps.sh` | Python wheels (co-repo generic form, same as `u1-extras`/`reference-python-plugins`/`all-the-tags`) | `pip download --platform manylinux2014_aarch64 --python-version 3.11 --implementation cp --abi cp311/abi3/none` | same `ensure_baked`/`check_baked_deps` gate in `pack-plugins.sh`: refuses to pack a plugin declaring `requirements.txt`/`klipper_requirements.txt` without `files/wheels`/`files/site-packages`, invokes the repo's `bake-deps.sh`, fails loud if still missing |
| `plugins/u1-extras/scripts/bake-deps.sh` | Python wheels + Klipper/Moonraker-extra site-packages | same `pip download` invocation | same `pack-plugins.sh` gate |
| `plugins/reference-python-plugins/scripts/bake-deps.sh` | Python wheels + site-packages | same | same gate |
| `plugins/all-the-tags/scripts/bake-deps.sh` | Python wheels + site-packages | same | same gate |
| `plugins/u1-extras/prometheus-exporter/build.sh` | Cross Go binary (static, `CGO_ENABLED=0`) | `GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build`, no Docker/QEMU (Go cross-compiles natively) | plugin-owned `build.sh`, NOT wired into a generic `ensure_baked` check (the packer's gate is Python-deps-shaped); invoked manually/by CI, not auto-run by `pack-plugins.sh` |
| `plugins/u1-extras/system-utils/build.sh` | Static system binaries (pre-built upstream releases, SHA-pinned download, no compile) | fetches `curl-linux-aarch64-glibc` + `rsync ... centos-8-aarch64` release tarballs, sha256-verified | same: manual/CI-invoked, not gated by `pack-plugins.sh`'s Python-only `ensure_baked` |
| `plugins/u1-hw-camera/scripts/build.sh` | Orchestrator: chains `toolchain/build.sh` then `scripts/pack.sh` | delegates | n/a (thin wrapper) |
| `plugins/u1-hw-camera/toolchain/build.sh` + `toolchain/Dockerfile` | Native C binaries + `.so` (v4l2-mpp apps, Rockchip MPP, libdatachannel/WebRTC, live555/RTSP) | `docker buildx --platform linux/arm64` (QEMU on x86 runners), `FROM --platform=linux/arm64 debian:bookworm`, vendored pinned-commit deps, `make install DESTDIR=/dist` | `.github/workflows/release.yml` runs `toolchain/build.sh` then `scripts/pack.sh` on push to `plugin/**\|src/**\|toolchain/**\|scripts/**`; validates every expected binary/`.so`/HTML asset exists before packing, fails otherwise. THIS IS THE MODEL PACKET 4'S `.ko` CROSS-BUILD COPIES. |
| `Bespok3d/scripts/pack-plugins.sh` | Packer / gate, not a builder | n/a | central `ensure_baked`/`check_baked_deps`/`find_baker` (lines ~249-320): walks up to the owning repo's `scripts/bake-deps.sh`, refuses to emit a `.b3` for a plugin declaring Python deps without baked artifacts; a Python-deps-only gate today |
| every co-repo `scripts/pack.sh` | Packer (zips manifest + `files/` + `doc/` into `.b3`, per-file sha256 + mode into manifest) | n/a, packages whatever `files/` contains | slim per-repo port of the monorepo packer; no baking logic, assumes `files/` is already complete |
| **kernel module (`.ko`)** | NOT YET EXISTING: packet 3/4's target class | new cross-build path modeled on `u1-hw-camera` (Docker/QEMU arm64) but against the RK BSP kernel source + junior's `.config`, `CONFIG_TUN=m`, `make -C <kernel> M=... modules` | needs a new `pack-plugins.sh` gate analogous to `ensure_baked`: refuse to pack a `kernel-module`-class plugin without a baked `.ko` matching the declared `vermagic` variants |

### Gaps this exposes for packet 9 (consolidation)

- `pack-plugins.sh`'s `ensure_baked` gate only understands the Python-deps artifact class. Go binaries
  (`prometheus-exporter`), static system binaries (`system-utils`), and native C/`.so` (`u1-hw-camera`)
  each have their OWN ad hoc `build.sh` with no shared "refuse to pack unbaked" enforcement from the
  central packer: that enforcement lives only in `u1-hw-camera`'s own CI workflow (asset-existence
  check), not generically.
  - `prometheus-exporter/build.sh` and `system-utils/build.sh` are NOT invoked from
    `pack-plugins.sh`/`bake-deps.sh`; they appear to be run manually/out-of-band before packing. Confirm
    this is intentional before packet 9 assumes a single consolidated gate.
- The `.ko` artifact class does not exist yet: no placement class, no baking gate, no variant selection
  tied to kernel `vermagic`. Packet 3 is the first consumer of a fact that does not flow anywhere today
  (`vermagic`/`kernel_release`), which packet 2's variant engine + facts plumbing must add.
- Every existing cross-build path targets a FIXED aarch64 ABI (glibc/manylinux, Rockchip Debian base). A
  kernel module is the one class where "target platform" is not just an arch tuple but an exact kernel
  build (source point + `.config` + toolchain, keyed on `vermagic`/`kernel_release`, not
  `arch`/`fw_min`/`fw_max`). Packet 9 should call this out as a categorically different variant axis.

## Flag for the plan (corrected)

**tun is MODULE-BUILDABLE, NOT blocked.** No packet is blocked by kernel-source availability. The
Watch-point "if the GPL kernel source is unavailable, the U1 `.ko` is blocked" does NOT trigger: the
source is the public Rockchip BSP (`rockchip-linux/kernel` develop-6.1, board `rk3562-evb2-ddr4-v10`),
we hold junior's exact `.config` (`/proc/config.gz`), MODVERSIONS is off (no `Module.symvers`), and
`CONFIG_MODULE_FORCE_LOAD=y` is a fallback. Packets 3, 4, 6, 7 all proceed as originally scoped.

---

## Session seed -> packet 2 (Variant engine + capabilities)

**State:** Packet 1 (Recon) DONE. Read-only; junior was only SSH'd for inspection (no writes, no service
restarts, no file changes; the running `.config` was copied off, which is a read). No `/comb` needed
(doc-only deliverable, no code diff); a read-through by Lucio substitutes.

**Next packet:** 2, Variant engine + capabilities (`daemon/core/conditions.py` pure `matches`/
`select_variant` over `{adapter, fw_min, fw_max, arch, board-class}`; `intent.py` `_resolve_variants`
pre-pass + `facts` param threaded to all callers; `arch` + memory/`constrained-board` facts across
jinni facts/base/U1 + capabilities schema + `wire.ts` mirror + fixtures).

- Model: Opus 4.8
- Effort: high
- Depends: 0 (not blocked by anything in this recon)
- Acceptance: `test_variant_selection_picks_matching_arch` + `test_no_matching_variant_is_skipped`
  pass; contract fixture regenerated + copied to app; `check.sh` green

**Carry into packet 2 (flag again at packets 3/4):** the kernel-module path is LIVE. Keep
`vermagic`/`kernel_release` in mind as a FUTURE variant dimension distinct from `arch`/`fw_min`/`fw_max`
(part B gap). Packet 2 need not implement it (packet 3 does), but `conditions.py` should not make adding
a new dim awkward. Packet 4's `.ko` cross-build uses `rockchip-linux/kernel` develop-6.1 + junior's
`.config` (saved this session) + `CONFIG_TUN=m` + suppressed localversion, Docker/QEMU-arm64 modeled on
`plugins/u1-hw-camera/toolchain/`.

**Clear line:** `/clear`

**Paste-ready prompt for packet 2:**

> Packet 2 of the VPN/kernel-module relay at `~/.claude/plans/ok-we-have-to-eventual-wren.md` (read it
> first, plus packet 1's finding doc at `plugins/networking/doc/recon-kernel-vpn.md`, and the Context
> section's referenced docs: ADR-0014, `Bespok3d/doc/package-format.md`, `daemon/core/intent.py`). Build
> the variant engine + capabilities: pure `daemon/core/conditions.py` (`matches`/`select_variant`, dims
> `{adapter, fw_min, fw_max, arch, board-class}`); `intent.py` `_resolve_variants` pre-pass + `facts`
> param threaded to all callers; `arch` + memory/`constrained-board` facts across jinni facts/base/U1 +
> capabilities schema + `wire.ts` mirror + fixtures. RULE ZERO (no em/en dash). Reuse before create.
> Every new capability field updates schema + `wire.ts` mirror + contract fixture (regenerate + copy to
> app) + `test_api.py` + jinni facts stub/override + `base.py` + `fakes.py` fake + U1
> `testkit/fixture.json`. `check.sh` green. `/comb` the diff. End with a `session-seed` handing off to
> packet 3 (Kernel-module mechanism, Opus 4.8 / high, specimen = `tun.ko`, which packet 1 confirmed
> module-buildable) and the `/clear` line; do not start packet 3.

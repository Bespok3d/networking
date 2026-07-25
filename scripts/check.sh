#!/usr/bin/env bash
# This repo's own gate: it must pass from this repo's root, with no sibling repo cloned except
# lib_bespok3d. Exits non-zero on any failure.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The shared gate helpers and the detectors that enforce a workspace-wide rule live in one place.
# See lib_bespok3d/tooling/README.md. This is the only line that knows where they are.
B3D_TOOLING="${B3D_TOOLING:-$REPO_ROOT/lib_bespok3d/tooling}"
# shellcheck source=/dev/null
. "$B3D_TOOLING/gate-lib.sh"

cd "$REPO_ROOT" || exit 1

echo ""
echo "networking gate"

b3d_python_tools

# Both wrappers are shell, so their suites are shell too: they run the real script against fake
# tailscaled / zerotier binaries, with no network and no device.
run_check "ts-run"  sh "$REPO_ROOT/tailscale/tests/run.sh"
run_check "zt-run"  sh "$REPO_ROOT/zerotier/tests/run.sh"
# A script, not a pytest module: it merges a stock [authorization] block with the shipped include
# and asserts the tailnet range is added without dropping a stock one.
run_check "moonraker trust"  "$B3D_PY" "$REPO_ROOT/tailscale/tests/test_moonraker_trust.py"

workflow_pinning_check "$REPO_ROOT"
em_dash_check "$REPO_ROOT"
shellcheck_repo "$REPO_ROOT"

gate_summary || exit 1

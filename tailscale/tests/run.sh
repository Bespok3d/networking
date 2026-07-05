#!/bin/sh
# Regression tests for src/ts-run, run against fake tailscaled/tailscale stubs (no real binaries,
# no network, no device needed). Exercises the start/wait-for-socket/join/stop sequence that is the
# whole reason this wrapper exists; the daemon's own install.service/variant-selection mechanism is
# covered by daemon/tests, not re-tested here.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
TS_RUN="$HERE/../src/ts-run"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# A stub standing in for tailscaled: creates the socket file it was told to listen on, records its
# own pid, and sleeps until killed, so the test can exercise readiness-wait and stop/cleanup.
cat > "$WORK/tailscaled" <<'EOF'
#!/bin/sh
for arg in "$@"; do
  case "$arg" in
    --socket=*) SOCK="${arg#--socket=}" ;;
    --cleanup) echo "cleanup" > "$(dirname "$0")/cleanup-invoked"; exit 0 ;;
  esac
done
echo "$$" > "$(dirname "$0")/tailscaled-pid"
: > "$SOCK"
trap 'rm -f "$SOCK"; exit 0' TERM
while :; do sleep 1; done
EOF
chmod +x "$WORK/tailscaled"

# A stub standing in for tailscale (the CLI): records the args it was called with, so the test can
# check the join call used the right socket and auth key. Fails on purpose when
# tailscale-should-fail exists, to exercise ts-run's behavior when a real join is rejected.
cat > "$WORK/tailscale" <<'EOF'
#!/bin/sh
echo "$*" > "$(dirname "$0")/tailscale-invoked"
[ -f "$(dirname "$0")/tailscale-should-fail" ] && exit 1
exit 0
EOF
chmod +x "$WORK/tailscale"

cp "$TS_RUN" "$WORK/ts-run"
chmod +x "$WORK/ts-run"

wait_for() {
  path="$1"
  tries=0
  while [ ! -e "$path" ]; do
    tries=$((tries + 1))
    [ "$tries" -ge 50 ] && fail "timed out waiting for $path"
    sleep 0.2 2>/dev/null || sleep 1
  done
}

# 1. A malformed auth key (no tskey-auth- prefix) must be rejected before tailscaled ever starts.
BAD_HOME="$WORK/home-bad"
if "$WORK/ts-run" "$BAD_HOME" "not-a-real-key" 2>/dev/null; then
  fail "ts-run accepted a malformed auth key instead of rejecting it"
fi
[ -e "$BAD_HOME" ] && fail "ts-run touched the data dir before validating the auth key"

# 2. An auth key with embedded whitespace (a plausible copy-paste artifact) must be rejected too.
if "$WORK/ts-run" "$WORK/home-whitespace" "tskey-auth-has space" 2>/dev/null; then
  fail "ts-run accepted an auth key containing whitespace instead of rejecting it"
fi

# 3. A well-formed key: tailscaled starts, the socket appears, tailscale up is invoked with the
# right socket and key, then stopping ts-run tears both down.
HOME_DIR="$WORK/home1"
"$WORK/ts-run" "$HOME_DIR" "tskey-auth-testonly-000000000000" &
RUN_PID=$!

wait_for "$WORK/tailscale-invoked"

grep -q -- "--socket=$HOME_DIR/tailscaled.sock" "$WORK/tailscale-invoked" \
  || fail "tailscale up was not called with the expected socket path"
grep -q -- "--auth-key=tskey-auth-testonly-000000000000" "$WORK/tailscale-invoked" \
  || fail "tailscale up was not called with the configured auth key"
[ -f "$WORK/tailscaled-pid" ] || fail "tailscaled was never started"

kill -TERM "$RUN_PID"
wait "$RUN_PID" 2>/dev/null || true

[ -f "$WORK/cleanup-invoked" ] || fail "tailscaled --cleanup was not invoked on stop"
[ -e "$HOME_DIR/tailscaled.sock" ] && fail "tailscaled socket was not removed on stop"

# 4. A rejected join (tailscale up exits nonzero): under `set -e` this must still run cleanup, not
# leave tailscaled orphaned. This is the failure mode a real expired/revoked auth key produces.
rm -f "$WORK/tailscale-invoked" "$WORK/cleanup-invoked" "$WORK/tailscaled-pid"
: > "$WORK/tailscale-should-fail"
REJECT_HOME="$WORK/home-reject"
if "$WORK/ts-run" "$REJECT_HOME" "tskey-auth-rejected-000000000000" >/dev/null 2>&1; then
  fail "ts-run should have exited nonzero when tailscale up was rejected"
fi
[ -f "$WORK/cleanup-invoked" ] || fail "a rejected join must still run tailscaled --cleanup"
[ -f "$WORK/tailscaled-pid" ] && kill -0 "$(cat "$WORK/tailscaled-pid")" 2>/dev/null \
  && fail "tailscaled was left running after a rejected join"
rm -f "$WORK/tailscale-should-fail"

# 5. tailscaled crashing on its own after a successful join (not stopped by us) must still run
# cleanup, the same as the ZeroTier device-verify's own account of stop() vs a self-exit.
rm -f "$WORK/tailscale-invoked" "$WORK/cleanup-invoked" "$WORK/tailscaled-pid"
CRASH_HOME="$WORK/home-crash"
"$WORK/ts-run" "$CRASH_HOME" "tskey-auth-testonly-000000000000" &
RUN_PID=$!
wait_for "$WORK/tailscaled-pid"
kill -KILL "$(cat "$WORK/tailscaled-pid")"
wait "$RUN_PID" 2>/dev/null || true
[ -f "$WORK/cleanup-invoked" ] || fail "tailscaled --cleanup was not invoked after tailscaled self-crashed"

echo "All ts-run tests passed."

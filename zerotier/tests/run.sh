#!/bin/sh
# Regression tests for src/zt-run, run against a fake zerotier-one stub (no real binary, no
# network, no device needed). Exercises the join-marker + stale-marker-cleanup logic that is the
# whole reason this wrapper exists; the daemon's own install.service/variant-selection mechanism is
# covered by daemon/tests, not re-tested here.
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
ZT_RUN="$HERE/../src/zt-run"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A stub standing in for the real zerotier-one binary: it just records the home dir it was called
# with and exits 0 immediately (zt-run execs it in the foreground; a real run blocks forever, this
# stub does not need to since the test only checks the marker files zt-run leaves behind).
cat > "$WORK/zerotier-one" <<'EOF'
#!/bin/sh
echo "called with: $1" > "$1/stub-invoked"
EOF
chmod +x "$WORK/zerotier-one"
cp "$ZT_RUN" "$WORK/zt-run"
chmod +x "$WORK/zt-run"

fail() { echo "FAIL: $1" >&2; exit 1; }
count_markers() { find "$1/networks.d" -maxdepth 1 -name '*.conf' | wc -l | tr -d ' '; }

# 1. First join: creates the marker and invokes zerotier-one with the home dir.
HOME_DIR="$WORK/home1"
"$WORK/zt-run" "$HOME_DIR" aaaaaaaaaa000001
[ -f "$HOME_DIR/networks.d/aaaaaaaaaa000001.conf" ] || fail "join marker not created"
[ -f "$HOME_DIR/stub-invoked" ] || fail "zerotier-one was not invoked"
grep -q "called with: $HOME_DIR" "$HOME_DIR/stub-invoked" || fail "zerotier-one invoked with wrong home dir"

# 2. Re-run with the same network id: idempotent, marker still present, still exactly one marker.
"$WORK/zt-run" "$HOME_DIR" aaaaaaaaaa000001
[ "$(count_markers "$HOME_DIR")" = "1" ] || fail "expected exactly one marker after a repeat join"

# 3. A marker this wrapper did not create (a user's manual `zerotier-cli join` over SSH, say) must
# survive a restart untouched: zt-run only ever removes the marker IT previously created.
: > "$HOME_DIR/networks.d/cccccccccc000003.conf"

# 4. Switching network id: the marker zt-run previously created is removed, the new one is created,
# and the foreign marker from step 3 is left alone.
"$WORK/zt-run" "$HOME_DIR" bbbbbbbbbb000002
[ -f "$HOME_DIR/networks.d/bbbbbbbbbb000002.conf" ] || fail "new join marker not created"
[ -f "$HOME_DIR/networks.d/aaaaaaaaaa000001.conf" ] && fail "stale marker from the old network id was not removed"
[ -f "$HOME_DIR/networks.d/cccccccccc000003.conf" ] || fail "a foreign marker zt-run never created was wrongly removed"
[ "$(count_markers "$HOME_DIR")" = "2" ] || fail "expected the new marker plus the untouched foreign one"

# 5. A network id that is not 16 hex digits (a stray value, or one containing a path separator)
# must be rejected before it ever reaches a path, not crash while building one.
BAD_HOME="$WORK/home-bad"
if "$WORK/zt-run" "$BAD_HOME" "../../etc/passwd" 2>/dev/null; then
  fail "zt-run accepted a malformed network id instead of rejecting it"
fi
[ -e "$BAD_HOME" ] && fail "zt-run touched the home dir before validating the network id"

echo "All zt-run tests passed."

#!/bin/sh
# Regression tests for src/zt-run, run against a fake zerotier-one stub (no real binary, no
# network, no device needed). Exercises the read-id-from-file + join-marker + stale-marker-cleanup
# logic that is the whole reason this wrapper exists; the daemon's own install.templates/
# install.service mechanism is covered by daemon/tests, not re-tested here.
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
# Stand in for the daemon rendering install.templates: write the network id into the file zt-run
# reads, the same way a fresh install or a reconfigure re-render does.
render_id() { printf '%s\n' "$2" > "$1"; }

ID_FILE="$WORK/network-id"

# 1. First join: reads the id from its file, creates the marker, invokes zerotier-one with the home
# dir.
HOME_DIR="$WORK/home1"
render_id "$ID_FILE" aaaaaaaaaa000001
"$WORK/zt-run" "$HOME_DIR" "$ID_FILE"
[ -f "$HOME_DIR/networks.d/aaaaaaaaaa000001.conf" ] || fail "join marker not created"
[ -f "$HOME_DIR/stub-invoked" ] || fail "zerotier-one was not invoked"
grep -q "called with: $HOME_DIR" "$HOME_DIR/stub-invoked" || fail "zerotier-one invoked with wrong home dir"

# 2. Re-run with the same file: idempotent, marker still present, still exactly one marker.
"$WORK/zt-run" "$HOME_DIR" "$ID_FILE"
[ "$(count_markers "$HOME_DIR")" = "1" ] || fail "expected exactly one marker after a repeat join"

# 3. A marker this wrapper did not create (a user's manual `zerotier-cli join` over SSH, say) must
# survive a restart untouched: zt-run only ever removes the marker IT previously created.
: > "$HOME_DIR/networks.d/cccccccccc000003.conf"

# 4. Switching network id THE WAY A RECONFIGURE DOES: the daemon re-renders the SAME id file with a
# new value and restarts the service. This is the whole point of reading the id from a file instead
# of a baked-in argv value. The marker zt-run previously created is removed, the new one created, and
# the foreign marker from step 3 left alone.
render_id "$ID_FILE" bbbbbbbbbb000002
"$WORK/zt-run" "$HOME_DIR" "$ID_FILE"
[ -f "$HOME_DIR/networks.d/bbbbbbbbbb000002.conf" ] || fail "new join marker not created after re-render"
[ -f "$HOME_DIR/networks.d/aaaaaaaaaa000001.conf" ] && fail "stale marker from the old network id was not removed"
[ -f "$HOME_DIR/networks.d/cccccccccc000003.conf" ] || fail "a foreign marker zt-run never created was wrongly removed"
[ "$(count_markers "$HOME_DIR")" = "2" ] || fail "expected the new marker plus the untouched foreign one"

# 5. A network id that is not 16 hex digits (a stray value, or one containing a path separator)
# must be rejected before it ever reaches a path, not crash while building one.
BAD_HOME="$WORK/home-bad"
BAD_FILE="$WORK/bad-id"
render_id "$BAD_FILE" "../../etc/passwd"
if "$WORK/zt-run" "$BAD_HOME" "$BAD_FILE" 2>/dev/null; then
  fail "zt-run accepted a malformed network id instead of rejecting it"
fi
[ -e "$BAD_HOME" ] && fail "zt-run touched the home dir before validating the network id"

# 6. A missing id file (an unconfigured or half-installed plugin) must fail with a clear error, not
# join an empty/garbage network.
MISSING_HOME="$WORK/home-missing"
if "$WORK/zt-run" "$MISSING_HOME" "$WORK/does-not-exist" 2>/dev/null; then
  fail "zt-run ran instead of failing on a missing network id file"
fi

echo "All zt-run tests passed."

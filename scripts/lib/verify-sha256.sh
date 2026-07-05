# Shared by every plugin's build.sh in this co-repo: verify a downloaded file's sha256 before
# using it. This is the third occurrence of this exact pattern across the workspace (zerotier,
# tailscale, and plugins/u1-extras/system-utils in a sibling repo), which is this project's own
# rule-of-three trigger to extract a shared helper; the sibling repo's copy is a separate git repo
# and stays as its own copy until a future build-system consolidation unifies them.
#
# Usage: . "$HERE/../scripts/lib/verify-sha256.sh"; verify_sha256 "$file" "$expected_sha256"
verify_sha256() {
  echo "$2  $1" | sha256sum -c - >/dev/null
}

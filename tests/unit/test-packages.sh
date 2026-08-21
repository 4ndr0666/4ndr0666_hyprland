#!/bin/bash
# Golden Unit Protocol: package core contract tests.
# These tests replace pacman, sudo, and the AUR helper with deterministic
# fixtures. No real system package manager is invoked.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORE="$ROOT/install-scripts/core/packages.sh"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

FAKEBIN="$TMPDIR/bin"
STATE="$TMPDIR/installed"
LOG="$TMPDIR/install.log"
MANIFEST="$TMPDIR/packages.manifest"
mkdir -p "$FAKEBIN"
touch "$STATE" "$LOG" "$MANIFEST"

cat > "$FAKEBIN/pacman" <<'EOF'
#!/bin/bash
set -u
state="${FAKE_PACMAN_STATE:?}"

case "${1:-}" in
  -Q)
    grep -Fqx -- "${2:-}" "$state"
    ;;
  -S)
    if [[ "${FAKE_PACMAN_FAIL:-0}" == 1 ]]; then
      exit 17
    fi
    shift
    while (($#)); do
      [[ "$1" == -- ]] && { shift; break; }
      shift
    done
    printf '%s\n' "$@" >> "$state"
    ;;
  -R)
    shift
    while (($#)); do
      [[ "$1" == -- ]] && { shift; break; }
      shift
    done
    for pkg in "$@"; do
      sed -i "\\|^${pkg}$|d" "$state"
    done
    ;;
esac
EOF

cat > "$FAKEBIN/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF

cat > "$FAKEBIN/yay" <<'EOF'
#!/bin/bash
set -u
state="${FAKE_PACMAN_STATE:?}"
if [[ "${1:-}" == -S ]]; then
  shift
  while (($#)); do
    [[ "$1" == -- ]] && { shift; break; }
    shift
  done
  printf '%s\n' "$@" >> "$state"
  exit 0
fi
if [[ "${1:-}" == -Q ]]; then
  grep -Fqx -- "${2:-}" "$state"
fi
EOF

chmod +x "$FAKEBIN"/*
export PATH="$FAKEBIN:$PATH"
export FAKE_PACMAN_STATE="$STATE"
export PACKAGE_MANIFEST="$MANIFEST"
export LOG

source "$CORE"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  grep -Fqx -- "$1" "$2" || fail "expected '$1' in $2"
}

assert_not_contains() {
  if grep -Fqx -- "$1" "$2"; then
    fail "did not expect '$1' in $2"
  fi
}

# Existing packages must never become installer-owned.
printf '%s\n' existing > "$STATE"
: > "$MANIFEST"
package_install existing
assert_not_contains existing "$MANIFEST"

# A successful official transaction records only newly installed requests.
printf '%s\n' existing > "$STATE"
: > "$MANIFEST"
package_install existing newpkg
assert_contains newpkg "$STATE"
assert_contains newpkg "$MANIFEST"
assert_not_contains existing "$MANIFEST"

# The package-manager exit status must propagate; package presence is not a
# success oracle.
printf '%s\n' existing > "$STATE"
: > "$MANIFEST"
export FAKE_PACMAN_FAIL=1
if package_install brokenpkg; then
  fail "failed package transaction returned success"
fi
assert_not_contains brokenpkg "$MANIFEST"
unset FAKE_PACMAN_FAIL

# AUR installation requires an explicit helper and records ownership only
# after the helper exits successfully.
printf '%s\n' existing > "$STATE"
: > "$MANIFEST"
package_install_aur aurpkg
assert_contains aurpkg "$STATE"
assert_contains aurpkg "$MANIFEST"

printf 'PASS: package core\n'

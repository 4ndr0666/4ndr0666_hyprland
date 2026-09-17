#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HARNESS="$ROOT/tests/oma/run-oma.sh"

[[ -r "$HARNESS" ]] || { printf '[FAIL] O.M.A. harness is unavailable.\n' >&2; exit 1; }

assert_contains() {
  local needle="$1"
  grep -F -- "$needle" "$HARNESS" >/dev/null || {
    printf '[FAIL] O.M.A. harness is missing required contract: %s\n' "$needle" >&2
    exit 1
  }
}

assert_absent() {
  local needle="$1"
  if grep -F -- "$needle" "$HARNESS" >/dev/null; then
    printf '[FAIL] O.M.A. harness contains forbidden contract: %s\n' "$needle" >&2
    exit 1
  fi
}

assert_contains 'case "$MODE" in'
assert_contains '--inventory|--verify)'
assert_contains 'PACMAN_VERSION="$(pacman --version 2>&1 | awk'
assert_contains '"dns_nameservers=$DNS_NAMESERVERS"'
assert_contains '[[ "$PACMAN_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]'
assert_contains '[[ "$RELEASE_REF" =~ ^[0-9a-fA-F]{40}$ ]]'
assert_contains '"memory_kb=$MEMORY_KB"'
assert_contains 'printf '\''hostname=%s\\n'\'' "$(uname -n)"'
assert_contains 'bash "$ROOT/tests/unit/run-golden-units.sh"'
assert_contains 'bash "$ROOT/install.sh" --dry-run'
assert_contains 'sha256sum "$EVIDENCE" > "$EVIDENCE.sha256"'
assert_absent '$(hostname)'
assert_absent 'exit || true'
assert_absent 'pacman --version | awk '\''/^Pacman'

printf '%s\n' 'O.M.A. harness execution contract: PASS'

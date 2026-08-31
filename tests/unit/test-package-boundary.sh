#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

PACKAGE_SURFACES=(
  "$ROOT/install-scripts"
  "$ROOT/assets/hyprland-install"
)

if grep -REn '(^|[[:space:]])(sudo[[:space:]]+)?pacman[[:space:]]+-[SRUu]' \
  "${PACKAGE_SURFACES[@]}" --include='*.sh' --exclude-dir=core --exclude='pacman.sh' >/tmp/package-boundary.out 2>&1; then
  cat /tmp/package-boundary.out >&2
  fail 'direct pacman package mutations exist outside the package core'
fi

if grep -REn '\$ISAUR[[:space:]]+-Syu|makepkg[[:space:]]+-si.*\|[[:space:]]*tee' \
  "${PACKAGE_SURFACES[@]}" --include='*.sh' --exclude-dir=core >/tmp/package-boundary.out 2>&1; then
  cat /tmp/package-boundary.out >&2
  fail 'legacy AUR/system-update transaction logic remains outside the bootstrap core'
fi

if grep -REn 'Global_functions\.sh' \
  "${PACKAGE_SURFACES[@]}" --include='*.sh' >/tmp/package-boundary.out 2>&1; then
  cat /tmp/package-boundary.out >&2
  fail 'legacy Global_functions.sh dependency remains'
fi

rm -f /tmp/package-boundary.out
printf '[PASS] package boundary invariants\n'

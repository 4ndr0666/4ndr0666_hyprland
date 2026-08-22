#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/install-scripts/core/aur-bootstrap.sh"

fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

# The bootstrap must require an immutable 40-character revision.
grep -Eq 'AUR_YAY_BIN_REF:-' "$FILE" || fail 'yay immutable ref is not required'
grep -Eq 'AUR_PARU_BIN_REF:-' "$FILE" || fail 'paru immutable ref is not required'
grep -Eq '\[\[ "\$ref" =~ \^\[0-9a-fA-F\]\{40\}\$' "$FILE" || fail '40-character SHA validation is missing'

# Mutable clone/update patterns are forbidden in the bootstrap.
if grep -Eq 'git clone .*aur\.archlinux\.org|git pull|--depth=1 .*aur\.archlinux\.org' "$FILE"; then
  fail 'mutable AUR checkout pattern remains'
fi

grep -Eq 'git fetch .*origin "\$ref"' "$FILE" || fail 'pinned git fetch is missing'
grep -Eq 'rev-parse HEAD' "$FILE" || fail 'post-checkout revision verification is missing'

printf '[PASS] AUR bootstrap provenance invariants\n'

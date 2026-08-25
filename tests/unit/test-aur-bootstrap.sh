#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/install-scripts/core/aur-bootstrap.sh"

fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

# The bootstrap must require an immutable yay revision.
grep -Eq 'AUR_YAY_BIN_REF:-' "$FILE" || fail 'yay immutable ref is not required'
grep -Eq '\[\[ "\$ref" =~ \^\[0-9a-fA-F\]\{40\}\$' "$FILE" || fail '40-character SHA validation is missing'
grep -Fq 'Only yay-bin is supported.' "$FILE" || fail 'yay-only contract is missing'
grep -Fq 'https://aur.archlinux.org/yay-bin.git' "$FILE" || fail 'yay AUR repository is missing'
grep -Fq 'source "$PROVENANCE_FILE"' "$FILE" || fail 'repository-owned provenance is not loaded'

# Paru must not be part of the supported bootstrap contract.
grep -Eq 'paru|AUR_PARU_BIN_REF' "$FILE" && fail 'paru bootstrap support remains'

# Mutable clone/update patterns are forbidden in the bootstrap.
if grep -Eq 'git clone .*aur\.archlinux\.org|git pull|--depth=1 .*aur\.archlinux\.org' "$FILE"; then
  fail 'mutable AUR checkout pattern remains'
fi

grep -Fq 'git -C "$build_dir" fetch --quiet --depth=1 origin "$ref"' "$FILE" || fail 'pinned git fetch is missing'
grep -Fq 'git -C "$build_dir" rev-parse HEAD' "$FILE" || fail 'post-checkout revision verification is missing'
grep -Fq 'command -v yay' "$FILE" || fail 'yay postcondition is missing'
grep -Eq '^AUR_YAY_BIN_REF=[0-9a-fA-F]{40}$' "$ROOT/install-scripts/core/aur-provenance.conf" || fail 'provenance lock is missing or invalid'

printf '[PASS] yay-only AUR bootstrap provenance invariants\n'

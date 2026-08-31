#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UPDATE="$ROOT/scripts/lib_update.sh"

[[ -f "$UPDATE" ]] || { printf '%s\n' 'missing self-update helper' >&2; exit 1; }

grep -q 'run_repo_update()' "$UPDATE"
! grep -Eq 'git[[:space:]]+(stash|pull|fetch|merge|reset|checkout)' "$UPDATE"
grep -q 'In-place repository updates are disabled' "$UPDATE"
grep -q 'reviewed release.ref' "$UPDATE"

printf '%s\n' 'self-update boundary: PASS'

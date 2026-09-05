#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

[[ ! -e "$ROOT/scripts/lib_update.sh" ]]
! grep -R -n --exclude-dir=.git --exclude-dir=archive 'run_repo_update\|UPDATE_HELPER\|lib_update.sh' "$ROOT/copy.sh" "$ROOT/scripts" >/dev/null 2>&1
! grep -R -n --exclude-dir=.git --exclude-dir=archive 'git[[:space:]]\+\(stash\|pull\|fetch\|merge\|reset\|checkout\)' "$ROOT/copy.sh" "$ROOT/scripts" >/dev/null 2>&1

grep -q -- '--upgrade' "$ROOT/copy.sh"
grep -q -- '--express-upgrade' "$ROOT/copy.sh"

grep -q 'immutable bootstrap' "$ROOT/auto-install.sh" || grep -q 'release revision' "$ROOT/Distro-Hyprland.sh"

printf '%s\n' 'self-update boundary: PASS'

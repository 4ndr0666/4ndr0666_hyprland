#!/usr/bin/env bash
# Golden Unit: installer dry-run contract.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALLER="$ROOT/install.sh"

before="$(find "$ROOT" -maxdepth 1 -type d -name 'Install-Logs' -print)"
out="$(bash "$INSTALLER" --dry-run)"

grep -Fq '[DRY-RUN] PASS: installer graph is present and syntactically valid.' <<< "$out"
grep -Fq '[DRY-RUN] OK 00-base.sh' <<< "$out"
grep -Fq '[DRY-RUN] OK 02-Final-Check.sh' <<< "$out"

if [[ -n "$before" ]]; then
  test -d "$before"
else
  ! test -d "$ROOT/Install-Logs"
fi

printf '%s\n' 'installer-dry-run: PASS'

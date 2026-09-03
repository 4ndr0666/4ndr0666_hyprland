#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/hypr/scripts/OverviewToggle.sh"

[[ -f "$SCRIPT" ]] || {
  printf '%s\n' "Missing Quickshell overview script: $SCRIPT" >&2
  exit 1
}

grep -Fq 'set -Eeuo pipefail' "$SCRIPT"
grep -Fq 'qs ipc -c overview call overview toggle' "$SCRIPT"
grep -Fq 'qs -c overview' "$SCRIPT"
! grep -Fq 'ags' "$SCRIPT"
! grep -Fq '/home/andro/' "$SCRIPT"
! grep -Fq '/home/' "$SCRIPT"
! grep -Fq 'Neither Quickshell nor AGS' "$SCRIPT"

grep -Fq '[ERROR] Quickshell overview is unavailable.' "$SCRIPT"

grep -Fq "notify-send 'Overview' 'Quickshell overview is unavailable'" "$SCRIPT"

grep -Fq 'exit 1' "$SCRIPT"

printf '%s\n' 'Quickshell overview boundary: PASS'

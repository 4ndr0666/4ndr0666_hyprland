#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/hypr/scripts/Refresh.sh"

[[ -f "$SCRIPT" ]] || { printf '%s\n' 'missing Refresh.sh' >&2; exit 1; }
grep -Eq '^set -Eeuo pipefail$' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lacks strict shell lifecycle semantics' >&2; exit 1; }
grep -Eq '^trap cleanup EXIT$' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lacks unconditional cleanup' >&2; exit 1; }
grep -Eq 'started_pids=\(\)' "$SCRIPT" || { printf '%s\n' 'Refresh.sh does not track started runtime processes' >&2; exit 1; }
grep -Eq 'cleanup_started' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lacks startup rollback' >&2; exit 1; }
grep -Eq 'start_component' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lacks observed component startup boundary' >&2; exit 1; }
grep -Eq 'kill_if_running' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lost existing runtime teardown boundary' >&2; exit 1; }
if grep -Eq 'pkill .*2>/dev/null.*\|\| true' "$SCRIPT"; then
  printf '%s\n' 'Refresh.sh generically swallows authoritative process-control failures' >&2
  exit 1
fi
if grep -Eq 'waybar .*&|swaync .*&|qs .*&' "$SCRIPT"; then
  printf '%s\n' 'Refresh.sh contains detached runtime startup outside the lifecycle boundary' >&2
  exit 1
fi
if grep -Eq '^sleep [0-9]' "$SCRIPT"; then
  printf '%s\n' 'Refresh.sh uses fixed sleeps as lifecycle synchronization' >&2
  exit 1
fi

grep -Fq 'Refresh lifecycle failure' "$SCRIPT" || { printf '%s\n' 'Refresh.sh does not surface lifecycle failure' >&2; exit 1; }

printf '%s\n' 'Refresh lifecycle boundary: PASS'

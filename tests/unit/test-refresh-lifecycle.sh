#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/hypr/scripts/Refresh.sh"

[[ -f "$SCRIPT" ]] || { printf '%s\n' 'missing Refresh.sh' >&2; exit 1; }
grep -Eq '^set -Eeuo pipefail$' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lacks strict shell lifecycle semantics' >&2; exit 1; }
grep -Eq '^trap cleanup EXIT$' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lacks unconditional cleanup' >&2; exit 1; }
grep -Eq 'started_pids=\(\)' "$SCRIPT" || { printf '%s\n' 'Refresh.sh does not track started runtime processes' >&2; exit 1; }
grep -Eq 'cleanup_started' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lacks startup rollback' >&2; exit 1; }
grep -Eq 'restore_components=\(\)' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lacks pre-refresh component state capture' >&2; exit 1; }
grep -Eq 'record_component_state' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lacks transactional component state capture' >&2; exit 1; }
grep -Eq 'restore_component_state' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lacks transactional rollback' >&2; exit 1; }
grep -Eq 'start_component' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lacks observed component startup boundary' >&2; exit 1; }
grep -Eq 'stop_component' "$SCRIPT" || { printf '%s\n' 'Refresh.sh lacks explicit runtime teardown boundary' >&2; exit 1; }
if grep -Eq 'pkill .*2>/dev/null.*\|\| true' "$SCRIPT"; then
  printf '%s\n' 'Refresh.sh generically swallows authoritative process-control failures' >&2
  exit 1
fi
if grep -Eq '^[[:space:]]*(waybar|swaync|qs)([[:space:]].*)?&[[:space:]]*$' "$SCRIPT"; then
  printf '%s\n' 'Refresh.sh contains direct detached component startup outside the lifecycle boundary' >&2
  exit 1
fi
if grep -Eq '^[[:space:]]*sleep [0-9]' "$SCRIPT"; then
  printf '%s\n' 'Refresh.sh uses fixed sleeps as lifecycle synchronization' >&2
  exit 1
fi

grep -Fq 'Refresh lifecycle failure' "$SCRIPT" || { printf '%s\n' 'Refresh.sh does not surface lifecycle failure' >&2; exit 1; }
grep -Fq 'Refresh lifecycle rollback failed' "$SCRIPT" || { printf '%s\n' 'Refresh.sh does not surface rollback failure' >&2; exit 1; }

grep -Eq 'start_optional_component Quickshell qs' "$SCRIPT" || { printf '%s\n' 'optional Quickshell startup is outside the lifecycle boundary' >&2; exit 1; }
grep -Eq 'stop_component qs' "$SCRIPT" || { printf '%s\n' 'Quickshell replacement does not preserve existing refresh teardown semantics' >&2; exit 1; }
grep -Eq 'start_component waybar waybar' "$SCRIPT" || { printf '%s\n' 'Waybar startup is not lifecycle-observed' >&2; exit 1; }
grep -Eq 'start_component swaync swaync' "$SCRIPT" || { printf '%s\n' 'SwayNC startup is not lifecycle-observed' >&2; exit 1; }

grep -Eq 'started_pids=\(\)' "$SCRIPT" || { printf '%s\n' 'Refresh.sh does not clear process ownership state' >&2; exit 1; }
grep -Eq 'restore_components=\(\)' "$SCRIPT" || { printf '%s\n' 'Refresh.sh does not clear rollback state' >&2; exit 1; }

printf '%s\n' 'Refresh lifecycle boundary: PASS'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPS="$ROOT/scripts/lib_apps.sh"
REFRESH="$ROOT/config/hypr/scripts/Refresh.sh"
NOWAYBAR="$ROOT/config/hypr/scripts/RefreshNoWaybar.sh"

[[ -f "$APPS" && -f "$REFRESH" && -f "$NOWAYBAR" ]]

grep -q '^enable_quickshell()' "$APPS"
grep -q "grep -qx 'exec-once = qs'" "$APPS"
grep -q 'start_optional_component Quickshell qs' "$REFRESH"

if grep -Fq 'config/hypr/scripts/RefreshNoWaybar.sh' "$APPS"; then
  printf '%s\n' '[FAIL] Quickshell enablement retains an obsolete RefreshNoWaybar mutation.' >&2
  exit 1
fi

if grep -Fq '#pkill qs && qs &' "$APPS"; then
  printf '%s\n' '[FAIL] Quickshell enablement retains retired command-template coupling.' >&2
  exit 1
fi

if awk '/enable_quickshell\(\)/,/^}/' "$APPS" | grep -Eq 'sed -i.*qs|qs.*sed -i'; then
  printf '%s\n' '[FAIL] Quickshell enablement mutates refresh scripts instead of using the authoritative lifecycle.' >&2
  exit 1
fi

if grep -Eq 'qs >/dev/null 2>&1 &' "$NOWAYBAR"; then
  printf '%s\n' '[FAIL] Non-Waybar refresh contains an untracked Quickshell launch.' >&2
  exit 1
fi

printf '%s\n' '[PASS] Quickshell refresh connectivity contract'

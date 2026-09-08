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

grep -Fq 'config/hypr/scripts/RefreshNoWaybar.sh' "$APPS" && {
  printf '%s\n' '[FAIL] Quickshell enablement retains an obsolete RefreshNoWaybar mutation.' >&2
  exit 1
}

grep -Fq '#pkill qs && qs &' "$APPS" && {
  printf '%s\n' '[FAIL] Quickshell enablement retains retired command-template coupling.' >&2
  exit 1
}

grep -Fq 'sed -i' "$APPS" | grep -q qs && {
  printf '%s\n' '[FAIL] Quickshell enablement mutates refresh scripts instead of using the authoritative lifecycle.' >&2
  exit 1
}

grep -Eq 'qs >/dev/null 2>&1 &' "$NOWAYBAR" && {
  printf '%s\n' '[FAIL] Non-Waybar refresh contains an untracked Quickshell launch.' >&2
  exit 1
}

printf '%s\n' '[PASS] Quickshell refresh connectivity contract'

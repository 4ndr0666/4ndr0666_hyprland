#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/hypr/scripts/RefreshNoWaybar.sh"

[[ -f "$SCRIPT" ]]
grep -q '^set -Eeuo pipefail$' "$SCRIPT"
grep -q '^started_pids=()' "$SCRIPT"
grep -q '^cleanup_started()' "$SCRIPT"
grep -q '^rollback()' "$SCRIPT"
grep -q '^trap cleanup EXIT$' "$SCRIPT"
grep -q 'restore_rofi=1' "$SCRIPT"
grep -q 'swaync-client --reload-config' "$SCRIPT"
grep -q 'start_component RainbowBorders' "$SCRIPT"
grep -q 'started_pids=()' "$SCRIPT"

if grep -Eq 'pidof .*pkill|pkill .*\|\| true' "$SCRIPT"; then
    printf '%s\n' '[FAIL] non-Waybar refresh retains brittle teardown/suppression.' >&2
    exit 1
fi

if grep -Eq '^[[:space:]]*(RainbowBorders|rofi)([[:space:]].*)?&[[:space:]]*$' "$SCRIPT"; then
    printf '%s\n' '[FAIL] authoritative component launch remains detached and unobserved.' >&2
    exit 1
fi

if grep -q 'UserScripts}/RainbowBorders.sh" &' "$SCRIPT"; then
    printf '%s\n' '[FAIL] RainbowBorders launch bypasses lifecycle ownership tracking.' >&2
    exit 1
fi

printf '%s\n' '[PASS] non-Waybar refresh lifecycle contract'

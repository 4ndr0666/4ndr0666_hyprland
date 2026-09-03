#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/hypr/scripts/DarkLight.sh"

[[ -f "$SCRIPT" ]]
grep -Fq 'set -Eeuo pipefail' "$SCRIPT"
grep -Fq 'WallustAwww.sh' "$SCRIPT"
grep -Fq 'awww_cmd=(awww img)' "$SCRIPT"
grep -Fq '"${awww_cmd[@]}" "$next_wallpaper" "${effect[@]}"' "$SCRIPT"

! grep -nE 'command -v ags|\bags_style\b|ags -q|ags -t|ags &' "$SCRIPT" >/dev/null 2>&1
! grep -nE '^\$awww|\$awww "|\$effect' "$SCRIPT" >/dev/null 2>&1
! grep -nE '\$wallust_rofi|wallust_rofi=' "$SCRIPT" >/dev/null 2>&1
! grep -nE 'for pid in .*ags|for pid1 in .*ags' "$SCRIPT" >/dev/null 2>&1

printf '%s\n' 'DarkLight boundary: PASS'

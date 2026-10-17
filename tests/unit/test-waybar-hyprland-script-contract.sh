#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODULES="$ROOT/config/waybar/ModulesCustom"
QUICK_SETTINGS="$ROOT/config/hypr/scripts/4ndr0666_Quick_Settings.sh"

grep -Fq '"on-click": "$HOME/.config/hypr/scripts/4ndr0666_Quick_Settings.sh"' "$MODULES"
! grep -Fq 'Kool_Quick_Settings.sh' "$MODULES"
[[ -f "$QUICK_SETTINGS" ]]
bash -n "$QUICK_SETTINGS"

printf '%s\n' 'Waybar settings script contract: PASS'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODULES="$ROOT/config/waybar/ModulesCustom"
QUICK_SETTINGS="$ROOT/config/hypr/scripts/4ndr0666_Quick_Settings.sh"
DOTS_UPDATE="$ROOT/config/hypr/scripts/4ndr0666DotsUpdate.sh"

grep -Fq '"on-click": "$HOME/.config/hypr/scripts/4ndr0666_Quick_Settings.sh"' "$MODULES"
grep -Fq '"on-click": "bash $HOME/.config/hypr/scripts/4ndr0666DotsUpdate.sh"' "$MODULES"
! grep -Fq 'Kool_Quick_Settings.sh' "$MODULES"
! grep -Fq 'KooLsDotsUpdate.sh' "$MODULES"
[[ -f "$QUICK_SETTINGS" ]]
[[ -f "$DOTS_UPDATE" ]]
bash -n "$QUICK_SETTINGS"
bash -n "$DOTS_UPDATE"

printf '%s\n' 'Waybar-to-Hyprland script contract: PASS'

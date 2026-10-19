#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# RainbowBorders.bak.sh — Backup/inactive template for RainbowBorders.sh
# Restored and toggled by 4ndr0666_Quick_Settings.sh (Rainbow Borders Mode).

set -euo pipefail

EFFECT_TYPE="wallust_random"

apply_border_gradient() {
    local colors="$1"
    local angle="${2:-45deg}"
    if ! command -v hyprctl >/dev/null 2>&1; then
        return 0
    fi
    hyprctl dispatch "hl.config({ general = { [\"col.active_border\"] = \"$colors $angle\" } })" >/dev/null 2>&1 || true
}

exit 0

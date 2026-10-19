#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# RainbowBorders.bak.sh — Backup/inactive template for RainbowBorders.sh
# Restored and toggled by 4ndr0666_Quick_Settings.sh (Rainbow Borders Mode).

set -euo pipefail

EFFECT_TYPE="wallust_random"
WALLUST_HYPR_CONF="${HOME}/.config/hypr/wallust/wallust-hyprland.conf"
WALLUST_ROFI_CONF="${HOME}/.config/rofi/wallust/colors-rofi.rasi"

apply_border_gradient() {
    local colors="$1"
    local angle="${2:-270deg}"
    if ! command -v hyprctl >/dev/null 2>&1 || [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        return 0
    fi
    hyprctl dispatch "hl.config({ general = { [\"col.active_border\"] = \"$colors $angle\" } })" >/dev/null 2>&1 || true
}

collect_wallust_colors() {
    local -a extracted=()
    if [[ -f "$WALLUST_HYPR_CONF" ]]; then
        while IFS= read -r hex; do
            [[ -n "$hex" ]] && extracted+=("0xff${hex#\#}")
        done < <(grep -Eo '#[0-9A-Fa-f]{6}' "$WALLUST_HYPR_CONF" | head -n 10 || true)
    elif [[ -f "$WALLUST_ROFI_CONF" ]]; then
        while IFS= read -r hex; do
            [[ -n "$hex" ]] && extracted+=("0xff${hex#\#}")
        done < <(grep -Eo '#[0-9A-Fa-f]{6}' "$WALLUST_ROFI_CONF" | head -n 10 || true)
    fi

    if ((${#extracted[@]} < 2)); then
        extracted=(
            0xffff0000 0xffff7f00 0xffffff00 0xff00ff00 0xff00ffff
            0xff0000ff 0xff4b0082 0xff9400d3 0xffff1493 0xffff0000
        )
    fi
    printf '%s' "${extracted[*]}"
}

run_rainbow_borders() {
    local palette=""
    local angle="270deg"
    case "${EFFECT_TYPE:-wallust_random}" in
        wallust_random)
            palette="$(collect_wallust_colors)"
            angle="270deg"
            ;;
        rainbow)
            palette="0xffff0000 0xffff7f00 0xffffff00 0xff00ff00 0xff00ffff 0xff0000ff 0xff4b0082 0xff9400d3 0xffff1493 0xffff0000"
            angle="270deg"
            ;;
        gradient_flow)
            palette="$(collect_wallust_colors)"
            angle="$(( ($(date +%s) * 45) % 360 ))deg"
            ;;
        *)
            palette="$(collect_wallust_colors)"
            angle="45deg"
            ;;
    esac
    apply_border_gradient "$palette" "$angle"
}

run_rainbow_borders
exit 0

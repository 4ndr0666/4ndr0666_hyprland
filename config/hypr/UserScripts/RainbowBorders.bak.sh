#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# Dynamic border color effects for Hyprland 0.55+ Lua configuration.
# Managed by 4ndr0666_Quick_Settings.sh, Refresh.sh, and RefreshNoWaybar.sh.
EFFECT_TYPE="wallust_random"

set -Eeuo pipefail

WALLUST_CONF="$HOME/.config/hypr/wallust/wallust-hyprland.conf"

random_hex_rgba() {
    printf 'rgba(%02x%02x%02xff)' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256))
}

apply_border_gradient() {
    local colors="$1"
    local angle="${2:-45deg}"
    if ! command -v hyprctl >/dev/null 2>&1; then
        return 0
    fi
    hyprctl dispatch "hl.config({ general = { ["col.active_border"] = "$colors $angle" } })" >/dev/null 2>&1 ||
        hyprctl keyword general:col.active_border "$colors $angle" >/dev/null 2>&1 || true
}

apply_wallust_borders() {
    local -a palette=()
    if [[ -f "$WALLUST_CONF" ]]; then
        while IFS= read -r hex; do
            [[ -n "$hex" ]] && palette+=("rgba(${hex}ff)")
        done < <(sed -nE 's/^\$color([0-9]+)[[:space:]]*=[[:space:]]*rgb\(([0-9A-Fa-f]{6})\).*/\2/p' "$WALLUST_CONF")
    fi
    if ((${#palette[@]} >= 2)); then
        local c1="${palette[RANDOM % ${#palette[@]}]}"
        local c2="${palette[RANDOM % ${#palette[@]}]}"
        apply_border_gradient "$c1 $c2" "45deg"
    else
        apply_border_gradient "$(random_hex_rgba) $(random_hex_rgba)" "45deg"
    fi
}

case "${EFFECT_TYPE:-wallust_random}" in
    wallust_random)
        apply_wallust_borders
        ;;
    rainbow)
        apply_border_gradient "$(random_hex_rgba) $(random_hex_rgba) $(random_hex_rgba) $(random_hex_rgba)" "45deg"
        ;;
    gradient_flow)
        apply_border_gradient "$(random_hex_rgba) $(random_hex_rgba) $(random_hex_rgba)" "90deg"
        ;;
    *)
        apply_wallust_borders
        ;;
esac

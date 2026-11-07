#!/usr/bin/env bash
# /* ---- https://github.com/4ndr0666 ---- */
# Dynamic border color effects for Hyprland 0.55+ Lua configuration.
# Managed by 4ndr0666_Quick_Settings.sh and the refresh lifecycle.

set -Eeuo pipefail

WALLUST_CONF="${HOME}/.config/hypr/wallust/wallust-hyprland.conf"
EFFECT_TYPE="wallust_random"

random_hex_rgba() {
    printf 'rgba(%02x%02x%02xff)' "$((RANDOM % 256))" "$((RANDOM % 256))" "$((RANDOM % 256))"
}

apply_border_gradient() {
    local colors="$1"
    local angle="$2"

    command -v hyprctl >/dev/null 2>&1 || {
        printf '%s\n' 'RainbowBorders: hyprctl is unavailable.' >&2
        return 127
    }

    # All values passed here are generated hex colors or parsed six-digit
    # Wallust colors; angle is selected only by the fixed mode table below.
    local color lua_colors="" result
    local -a parts
    read -r -a parts <<< "$colors"
    [[ "$angle" =~ ^[0-9]+deg$ && ${#parts[@]} -gt 0 ]] || return 2
    for color in "${parts[@]}"; do
        [[ "$color" =~ ^rgba\([[:xdigit:]]{8}\)$ ]] || return 2
        lua_colors+="\"$color\","
    done
    result="$(hyprctl eval "hl.config({ general = { [\"col.active_border\"] = { colors = {$lua_colors}, angle = ${angle%deg} } } })")" || return $?
    [[ "${result//$'\n'/}" == ok ]] || { printf 'RainbowBorders: %s\n' "$result" >&2; return 1; }
}

apply_wallust_borders() {
    local -a palette=()
    local hex

    if [[ -r "$WALLUST_CONF" ]]; then
        while IFS= read -r hex; do
            [[ "$hex" =~ ^[[:xdigit:]]{6}$ ]] || continue
            palette+=("rgba(${hex}ff)")
        done < <(sed -nE 's/^\$color[0-9]+[[:space:]]*=[[:space:]]*rgb\(([0-9A-Fa-f]{6})\).*/\1/p' "$WALLUST_CONF")
    fi

    if ((${#palette[@]} >= 2)); then
        local first="${palette[RANDOM % ${#palette[@]}]}"
        local second="${palette[RANDOM % ${#palette[@]}]}"
        apply_border_gradient "$first $second" '45deg'
    else
        apply_border_gradient "$(random_hex_rgba) $(random_hex_rgba)" '45deg'
    fi
}

case "$EFFECT_TYPE" in
    wallust_random)
        apply_wallust_borders
        ;;
    rainbow)
        apply_border_gradient "$(random_hex_rgba) $(random_hex_rgba) $(random_hex_rgba) $(random_hex_rgba)" '45deg'
        ;;
    gradient_flow)
        apply_border_gradient "$(random_hex_rgba) $(random_hex_rgba) $(random_hex_rgba)" '90deg'
        ;;
    *)
        printf 'RainbowBorders: unsupported EFFECT_TYPE: %s\n' "$EFFECT_TYPE" >&2
        exit 2
        ;;
esac

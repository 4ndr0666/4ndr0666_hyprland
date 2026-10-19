#!/usr/bin/env bash
# /* ---- https://github.com/4ndr0666 ---- */
# Dynamic border color effects for Hyprland 0.55+ Lua configuration.
# Managed by 4ndr0666_Quick_Settings.sh and the refresh lifecycle.

set -Eeuo pipefail

WALLUST_CONF="${HOME}/.config/hypr/wallust/wallust-hyprland.conf"

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
    hyprctl dispatch "hl.config({ general = { [\"col.active_border\"] = \"$colors $angle\" } })" >/dev/null
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

    if (("${#palette[@]}" >= 2)); then
        local first="${palette[RANDOM % ${#palette[@]}]}"
        local second="${palette[RANDOM % ${#palette[@]}]}"
        apply_border_gradient "$first $second" '45deg'
    else
        apply_border_gradient "$(random_hex_rgba) $(random_hex_rgba)" '45deg'
    fi
}

EFFECT_TYPE="${EFFECT_TYPE:-wallust_random}"
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

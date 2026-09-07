#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  #
# Wallpaper Effects using ImageMagick (SUPER SHIFT W)

set -Eeuo pipefail

wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
wallpaper_output="$HOME/.config/hypr/wallpaper_effects/.wallpaper_modified"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
rofi_theme="$HOME/.config/rofi/config-wallpaper-effect.rasi"
iDIR="$HOME/.config/swaync/images"

FPS=60
TYPE="wipe"
DURATION=2
BEZIER=".43,1.19,1,.4"
AWWW_PARAMS=(--transition-fps "$FPS" --transition-type "$TYPE" --transition-duration "$DURATION" --transition-bezier "$BEZIER")

tmp_output=''
cleanup() {
    if [[ -n "$tmp_output" ]]; then
        rm -f -- "$tmp_output"
    fi
}
trap cleanup EXIT

atomic_copy() {
    local source="$1"
    local destination="$2"
    local directory
    directory="$(dirname -- "$destination")"
    tmp_output="$(mktemp "$directory/.wallpaper.XXXXXX")"
    cp -- "$source" "$tmp_output"
    mv -f -- "$tmp_output" "$destination"
    tmp_output=''
}

no-effects() {
    awww img -o "$focused_monitor" "$wallpaper_current" "${AWWW_PARAMS[@]}"
    wallust run "$wallpaper_current" -s
    "$SCRIPTSDIR/Refresh.sh"
    notify-send -u low -i "$iDIR/ja.png" "No wallpaper" "effects applied" 2>/dev/null || true
    atomic_copy "$wallpaper_current" "$wallpaper_output"
}

apply_effect() {
    local choice="$1"
    local destination="$2"

    case "$choice" in
        "Black & White")
            magick "$wallpaper_current" -colorspace gray -sigmoidal-contrast 10,40% "$destination"
            ;;
        "Blurred")
            magick "$wallpaper_current" -blur 0x10 "$destination"
            ;;
        "Charcoal")
            magick "$wallpaper_current" -charcoal 0x5 "$destination"
            ;;
        "Edge Detect")
            magick "$wallpaper_current" -edge 1 "$destination"
            ;;
        "Emboss")
            magick "$wallpaper_current" -emboss 0x5 "$destination"
            ;;
        "Frame Raised")
            magick "$wallpaper_current" +raise 150 "$destination"
            ;;
        "Frame Sunk")
            magick "$wallpaper_current" -raise 150 "$destination"
            ;;
        "Negate")
            magick "$wallpaper_current" -negate "$destination"
            ;;
        "Oil Paint")
            magick "$wallpaper_current" -paint 4 "$destination"
            ;;
        "Posterize")
            magick "$wallpaper_current" -posterize 4 "$destination"
            ;;
        "Polaroid")
            magick "$wallpaper_current" -polaroid 0 "$destination"
            ;;
        "Sepia Tone")
            magick "$wallpaper_current" -sepia-tone 65% "$destination"
            ;;
        "Solarize")
            magick "$wallpaper_current" -solarize 80% "$destination"
            ;;
        "Sharpen")
            magick "$wallpaper_current" -sharpen 0x5 "$destination"
            ;;
        "Vignette")
            magick "$wallpaper_current" -vignette 0x3 "$destination"
            ;;
        "Vignette-black")
            magick "$wallpaper_current" -background black -vignette 0x3 "$destination"
            ;;
        "Zoomed")
            magick "$wallpaper_current" -gravity Center -extent 1:1 "$destination"
            ;;
        *)
            printf 'Effect %q not recognized.\n' "$choice" >&2
            return 1
            ;;
    esac
}

main() {
    local options choice
    options=(
        "No Effects"
        "Black & White"
        "Blurred"
        "Charcoal"
        "Edge Detect"
        "Emboss"
        "Frame Raised"
        "Frame Sunk"
        "Negate"
        "Oil Paint"
        "Posterize"
        "Polaroid"
        "Sepia Tone"
        "Solarize"
        "Sharpen"
        "Vignette"
        "Vignette-black"
        "Zoomed"
    )

    choice="$(printf '%s\n' "${options[@]}" | LC_COLLATE=C sort | rofi -dmenu -i -config "$rofi_theme")"
    [[ -n "$choice" ]] || return 0

    if [[ "$choice" == "No Effects" ]]; then
        no-effects
        return 0
    fi

    notify-send -u normal -i "$iDIR/ja.png" "Applying:" "$choice effects" 2>/dev/null || true
    tmp_output="$(mktemp "$(dirname -- "$wallpaper_output")/.wallpaper.XXXXXX")"
    apply_effect "$choice" "$tmp_output"
    mv -f -- "$tmp_output" "$wallpaper_output"
    tmp_output=''

    for pid in swaybg mpvpaper; do
        killall -SIGUSR1 "$pid" 2>/dev/null || true
    done

    awww img -o "$focused_monitor" "$wallpaper_output" "${AWWW_PARAMS[@]}"
    wallust run "$wallpaper_output" -s
    "$SCRIPTSDIR/Refresh.sh"
    notify-send -u low -i "$iDIR/ja.png" "$choice" "effects applied" 2>/dev/null || true
}

focused_monitor="$(hyprctl monitors -j | jq -er '.[] | select(.focused) | .name')"
[[ -f "$wallpaper_current" ]] || { printf 'Current wallpaper is missing: %s\n' "$wallpaper_current" >&2; exit 1; }
[[ -f "$rofi_theme" ]] || { printf 'Wallpaper effect Rofi theme is missing: %s\n' "$rofi_theme" >&2; exit 1; }
main

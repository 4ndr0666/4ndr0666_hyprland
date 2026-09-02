#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  #
# Wallpaper Effects using ImageMagick (SUPER SHIFT W)

set -Eeuo pipefail

terminal=kitty
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
wallpaper_output="$HOME/.config/hypr/wallpaper_effects/.wallpaper_modified"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
rofi_theme="$HOME/.config/rofi/config-wallpaper-effect.rasi"

iDIR="$HOME/.config/swaync/images"
iDIRi="$HOME/.config/swaync/icons"

FPS=60
TYPE="wipe"
DURATION=2
BEZIER=".43,1.19,1,.4"
AWWW_PARAMS=(--transition-fps "$FPS" --transition-type "$TYPE" --transition-duration "$DURATION" --transition-bezier "$BEZIER")

no-effects() {
    awww img -o "$focused_monitor" "$wallpaper_current" "${AWWW_PARAMS[@]}"
    wallust run "$wallpaper_current" -s
    sleep 2
    "$SCRIPTSDIR/Refresh.sh"
    notify-send -u low -i "$iDIR/ja.png" "No wallpaper" "effects applied"
    cp -- "$wallpaper_current" "$wallpaper_output"
}

apply_effect() {
    local choice="$1"

    case "$choice" in
        "Black & White")
            magick "$wallpaper_current" -colorspace gray -sigmoidal-contrast 10,40% "$wallpaper_output"
            ;;
        "Blurred")
            magick "$wallpaper_current" -blur 0x10 "$wallpaper_output"
            ;;
        "Charcoal")
            magick "$wallpaper_current" -charcoal 0x5 "$wallpaper_output"
            ;;
        "Edge Detect")
            magick "$wallpaper_current" -edge 1 "$wallpaper_output"
            ;;
        "Emboss")
            magick "$wallpaper_current" -emboss 0x5 "$wallpaper_output"
            ;;
        "Frame Raised")
            magick "$wallpaper_current" +raise 150 "$wallpaper_output"
            ;;
        "Frame Sunk")
            magick "$wallpaper_current" -raise 150 "$wallpaper_output"
            ;;
        "Negate")
            magick "$wallpaper_current" -negate "$wallpaper_output"
            ;;
        "Oil Paint")
            magick "$wallpaper_current" -paint 4 "$wallpaper_output"
            ;;
        "Posterize")
            magick "$wallpaper_current" -posterize 4 "$wallpaper_output"
            ;;
        "Polaroid")
            magick "$wallpaper_current" -polaroid 0 "$wallpaper_output"
            ;;
        "Sepia Tone")
            magick "$wallpaper_current" -sepia-tone 65% "$wallpaper_output"
            ;;
        "Solarize")
            magick "$wallpaper_current" -solarize 80% "$wallpaper_output"
            ;;
        "Sharpen")
            magick "$wallpaper_current" -sharpen 0x5 "$wallpaper_output"
            ;;
        "Vignette")
            magick "$wallpaper_current" -vignette 0x3 "$wallpaper_output"
            ;;
        "Vignette-black")
            magick "$wallpaper_current" -background black -vignette 0x3 "$wallpaper_output"
            ;;
        "Zoomed")
            magick "$wallpaper_current" -gravity Center -extent 1:1 "$wallpaper_output"
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

    choice=$(printf '%s\n' "${options[@]}" | LC_COLLATE=C sort | rofi -dmenu -i -config "$rofi_theme")

    [[ -n "$choice" ]] || return 0

    if [[ "$choice" == "No Effects" ]]; then
        no-effects
    else
        notify-send -u normal -i "$iDIR/ja.png" "Applying:" "$choice effects"
        apply_effect "$choice"

        for pid in swaybg mpvpaper; do
            killall -SIGUSR1 "$pid" 2>/dev/null || true
        done

        sleep 1
        awww img -o "$focused_monitor" "$wallpaper_output" "${AWWW_PARAMS[@]}" &
        sleep 2
        wallust run "$wallpaper_output" -s &
        sleep 1
        "$SCRIPTSDIR/Refresh.sh"
        notify-send -u low -i "$iDIR/ja.png" "$choice" "effects applied"
    fi
}

if pidof rofi >/dev/null; then
    pkill rofi
fi

main
sleep 1

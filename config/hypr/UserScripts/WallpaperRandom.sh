#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# Script for Random Wallpaper ( CTRL ALT W)

set -Eeuo pipefail

wallDIR="$HOME/Wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"

focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
[[ -n "$focused_monitor" ]] || {
    printf '%s\n' '[ERROR] Unable to determine the focused monitor.' >&2
    exit 1
}

mapfile -d '' PICS < <(find -L "$wallDIR" -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.pnm' \
    -o -iname '*.tga' -o -iname '*.tiff' -o -iname '*.webp' -o -iname '*.bmp' \
    -o -iname '*.farbfeld' -o -iname '*.gif' \
\) -print0)

((${#PICS[@]})) || {
    printf '%s\n' '[ERROR] No supported wallpapers found.' >&2
    exit 1
}

RANDOMPICS="${PICS[RANDOM % ${#PICS[@]}]}"

# Transition config.
AWWW_PARAMS=(
    --transition-fps 30
    --transition-type random
    --transition-duration 1
    --transition-bezier .43,1.19,1,.4
)

if ! awww query >/dev/null 2>&1; then
    awww-daemon --format xrgb
fi

awww img -o "$focused_monitor" "$RANDOMPICS" "${AWWW_PARAMS[@]}"

# Generate and validate the palette from the exact wallpaper selected above.
"$SCRIPTSDIR/WallustAwww.sh" "$RANDOMPICS"

# Refresh consumers not reloaded by the Wallust palette boundary.
"$SCRIPTSDIR/Refresh.sh"

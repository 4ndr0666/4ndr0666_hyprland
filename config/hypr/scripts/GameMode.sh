#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# Game Mode. Turning off animations and visual effects.

set -Eeuo pipefail

notif="$HOME/.config/mako/images/ja.png"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
current_wallpaper="$HOME/.config/rofi/.current_wallpaper"

HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')

if [ "$HYPRGAMEMODE" = 1 ]; then
    hyprctl dispatch 'hl.config({
        animations = { enabled = false },
        decoration = {
            shadow = { enabled = false },
            blur = { enabled = false },
            rounding = 0,
        },
        general = {
            gaps_in = 0,
            gaps_out = 0,
            border_size = 1,
        },
    })'

    # UserDecorations.lua already keeps all window opacities at 1.0, so the
    # legacy catch-all opacity window rule was redundant and is retired.
    awww kill
    notify-send -e -u low -i "$notif" " Gamemode:" " enabled"
    sleep 0.1
    exit
else
    [[ -f "$current_wallpaper" ]] || {
        printf '%s\n' '[ERROR] Current wallpaper is unavailable; cannot leave game mode cleanly.' >&2
        exit 1
    }

    awww-daemon --format xrgb &
    sleep 0.1
    awww img "$current_wallpaper"
    "$SCRIPTSDIR/WallustAwww.sh" "$current_wallpaper"
    sleep 0.5
    hyprctl reload
    "$SCRIPTSDIR/Refresh.sh"
    notify-send -e -u normal -i "$notif" " Gamemode:" " disabled"
    exit
fi

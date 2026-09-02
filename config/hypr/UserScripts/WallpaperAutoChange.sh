#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# source https://wiki.archlinux.org/title/Hyprland#Using_a_script_to_change_wallpaper_every_X_minutes

# This script will randomly go through the files of a directory, setting it
# up as the wallpaper at regular intervals.

set -Eeuo pipefail

wallust_refresh="$HOME/.config/hypr/scripts/RefreshNoWaybar.sh"
wallust_script="$HOME/.config/hypr/scripts/WallustAwww.sh"

focused_monitor=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')
[[ -n "$focused_monitor" ]] || {
    printf '%s\n' '[ERROR] Unable to determine the focused monitor.' >&2
    exit 1
}

if [[ $# -lt 1 || ! -d "$1" ]]; then
    printf '%s\n' "Usage: $0 <dir containing images>" >&2
    exit 1
fi

# Edit below to control the images transition.
export SWWW_TRANSITION_FPS=60
export SWWW_TRANSITION_TYPE=simple

# This controls (in seconds) when to switch to the next image.
INTERVAL=1800

while true; do
    mapfile -d '' wallpapers < <(find "$1" -type f -print0 | shuf -z)
    ((${#wallpapers[@]})) || {
        printf '%s\n' '[ERROR] No wallpaper files found.' >&2
        exit 1
    }

    for img in "${wallpapers[@]}"; do
        awww img -o "$focused_monitor" "$img"
        # Generate and validate Wallust outputs once, from the exact image path.
        "$wallust_script" "$img"
        # Refresh only consumers not reloaded by WallustAwww.sh.
        "$wallust_refresh"
        sleep "$INTERVAL"
    done
done

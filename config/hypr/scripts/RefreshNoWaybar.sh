#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##

# Modified version of Refresh.sh that does not refresh Waybar.
# Used by automatic wallpaper change to refresh consumers that do not depend
# on Waybar's Wallust palette reload.

set -Eeuo pipefail

SCRIPTSDIR="$HOME/.config/hypr/scripts"
UserScripts="$HOME/.config/hypr/UserScripts"

# Kill already running processes.
_ps=(rofi)
for _prs in "${_ps[@]}"; do
    if pidof "${_prs}" >/dev/null; then
        pkill "${_prs}"
    fi
done

# Reload swaync.
swaync-client --reload-config

# Relaunch rainbow borders if the script exists.
if [[ -e "${UserScripts}/RainbowBorders.sh" ]]; then
    "${UserScripts}/RainbowBorders.sh" &
fi

exit 0

#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# Scripts for refreshing waybar, rofi, mako, wallust

SCRIPTSDIR="$HOME/.config/hypr/scripts"
UserScripts="$HOME/.config/hypr/UserScripts"

file_exists() {
  [[ -e "$1" ]]
}

# Cleanly terminate running UI instances
pkill -x waybar 2>/dev/null || true
pkill -x rofi 2>/dev/null || true
pkill -x mako 2>/dev/null || true

sleep 0.2

# Wallust color regeneration
if [[ -x "${SCRIPTSDIR}/WallustSwww.sh" ]]; then
  "${SCRIPTSDIR}/WallustSwww.sh"
fi

# Relaunch Waybar
waybar >/dev/null 2>&1 &

# Relaunch Mako
sleep 0.2
mako >/dev/null 2>&1 &

# Relaunch Rainbow Borders if active
sleep 0.5
if file_exists "${UserScripts}/RainbowBorders.sh"; then
  "${UserScripts}/RainbowBorders.sh" >/dev/null 2>&1 &
fi

exit 0
-- Segment 5

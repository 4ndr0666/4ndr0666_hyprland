#!/usr/bin/env bash
# 4ndr0666
#             === ROFI LAUNCHER === #

# Import Current Theme
UserScripts="$HOME/.config/hypr/UserScripts"
RASI="$UserScripts/rofi/4ndr0666.rasi"

# Kill Rofi if already running before execution
if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

# Run
rofi \
    -show drun \
	-theme "${RASI}"

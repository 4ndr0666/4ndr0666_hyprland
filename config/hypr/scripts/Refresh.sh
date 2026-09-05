#!/usr/bin/env bash
# === 4ndr0666 === #
# Refresh Waybar, Rofi, SwayNC, and the supported Quickshell session.
set -Eeuo pipefail

SCRIPTSDIR="$HOME/.config/hypr/scripts"
USER_SCRIPTS="$HOME/.config/hypr/UserScripts"

kill_if_running() {
  local process="$1"
  if pidof "$process" >/dev/null 2>&1; then
    pkill "$process"
  fi
}

kill_if_running waybar
kill_if_running rofi
kill_if_running swaync
kill_if_running swaybg

# Give Waybar a chance to consume the signal before its clean restart.
pkill -SIGUSR2 waybar 2>/dev/null || true

# Quickshell owns the desktop shell lifecycle; restart it only when present.
if command -v qs >/dev/null 2>&1; then
  pkill qs 2>/dev/null || true
  qs >/dev/null 2>&1 &
fi

# Restart Waybar and SwayNC after the shell has been refreshed.
sleep 0.1
waybar >/dev/null 2>&1 &
sleep 0.3
swaync >/dev/null 2>&1 &
swaync-client --reload-config

# Optional Rainbow Borders integration.
if [[ -x "$USER_SCRIPTS/RainbowBorders.sh" ]]; then
  "$USER_SCRIPTS/RainbowBorders.sh" &
fi

exit 0

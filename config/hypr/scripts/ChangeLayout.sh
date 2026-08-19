#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# Toggle Hyprland's master/dwindle layout.
#
# Layout-aware J/K navigation is implemented in configs/Keybinds.lua and
# reads general.layout at keypress time. This script therefore changes only
# the layout itself and does not mutate the Lua keybind registry.

set -u

notif="$HOME/.config/mako/images/ja.png"

if ! command -v hyprctl >/dev/null 2>&1; then
  printf '%s\n' "ChangeLayout: hyprctl not found." >&2
  exit 1
fi

layout=$(hyprctl -j getoption general:layout 2>/dev/null | jq -r '.str // empty')
case "$layout" in
  master)
    next_layout="dwindle"
    message="Dwindle Layout"
    ;;
  dwindle)
    next_layout="master"
    message="Master Layout"
    ;;
  *)
    printf 'ChangeLayout: unsupported current layout: %s\n' "${layout:-<empty>}" >&2
    exit 1
    ;;
esac

if ! hyprctl keyword general:layout "$next_layout" >/dev/null 2>&1; then
  printf 'ChangeLayout: failed to switch layout to %s.\n' "$next_layout" >&2
  exit 1
fi

if command -v notify-send >/dev/null 2>&1; then
  if [ -f "$notif" ]; then
    notify-send -e -u low -i "$notif" "$message"
  else
    notify-send -e -u low "$message"
  fi
fi

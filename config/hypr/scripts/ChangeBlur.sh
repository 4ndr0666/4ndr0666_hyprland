#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# Script for changing blurs on the fly

notif="$HOME/.config/mako/images"

STATE=$(hyprctl -j getoption decoration:blur:passes | jq ".int")

if [ "${STATE}" == "2" ]; then
    hyprctl dispatch 'hl.config({ decoration = { blur = { size = 2, passes = 1 } } })'
    notify-send -e -u low -i "$notif/note.png" " Less Blur"
else
    hyprctl dispatch 'hl.config({ decoration = { blur = { size = 5, passes = 2 } } })'
    notify-send -e -u low -i "$notif/ja.png" " Normal Blur"
fi

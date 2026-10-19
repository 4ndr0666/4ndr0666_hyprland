#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# For toggling touchpad in Hyprland 0.55+ using native Lua hl.device() IPC.
# Edit Touchpad_Device in ~/.config/hypr/UserConfigs/Laptops.lua according to `hyprctl devices`.

set -euo pipefail

notif="$HOME/.config/swaync/images/ja.png"
laptops_conf="$HOME/.config/hypr/UserConfigs/Laptops.lua"

touchpad_device="${TOUCHPAD_DEVICE:-}"
if [[ -z "$touchpad_device" && -f "$laptops_conf" ]]; then
    touchpad_device="$(
        awk -F= '
            /^[[:space:]]*(local[[:space:]]+)?Touchpad_Device[[:space:]]*=/ || /^\$Touchpad_Device[[:space:]]*=/ {
                val = $2
                sub(/[[:space:]]*(--|#).*$/, "", val)
                gsub(/^[[:space:]"'"'"']+|[[:space:]"'"'"']+$/, "", val)
                print val
                exit
            }
        ' "$laptops_conf"
    )"
fi

if [[ -z "$touchpad_device" ]]; then
    notify-send -u low -i "$notif" " Touchpad" " Device name not set (check Laptops.lua)"
    exit 1
fi

escaped_device="$(printf '%s' "$touchpad_device" | sed 's/\\/\\\\/g; s/"/\\"/g')"
status_file="${XDG_RUNTIME_DIR:-/tmp}/touchpad.status"

enable_touchpad() {
    printf "true" >"$status_file"
    notify-send -u low -i "$notif" " Enabling" " touchpad"
    hyprctl dispatch "hl.device({ name = \"$escaped_device\", enabled = true })"
}

disable_touchpad() {
    printf "false" >"$status_file"
    notify-send -u low -i "$notif" " Disabling" " touchpad"
    hyprctl dispatch "hl.device({ name = \"$escaped_device\", enabled = false })"
}

current_state="false"
if [[ -f "$status_file" ]]; then
    current_state="$(<"$status_file")"
fi

if [[ "$current_state" == "true" ]]; then
    disable_touchpad
else
    enable_touchpad
fi

#!/usr/bin/env bash
# /* ---- 💫 https://github.com/4ndr0666 💫 ---- */  ##
# For Searching via web browsers

config_file="$HOME/.config/hypr/UserConfigs/01-UserDefaults.lua"

if ! command -v jq >/dev/null 2>&1; then
    notify-send -u low "Rofi Search" "jq is required for URL encoding. Please install jq."
    exit 1
fi

if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file not found!" >&2
    exit 1
fi

Search_Engine=$(grep -E '^\s*local\s+search_engine\s*=' "$config_file" | sed -E 's/.*=\s*"([^"]*)".*/\1/')
[[ -z "$Search_Engine" ]] && Search_Engine="https://www.yandex.com/search?text={}"

rofi_theme="$HOME/.config/rofi/config-search.rasi"
msg='‼️ **note** ‼️ search via default web browser'

if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

query=$(printf '' | rofi -dmenu -config "$rofi_theme" -mesg "$msg")

if [[ -z "$query" ]]; then
    exit 0
fi

encoded_query=$(printf '%s' "$query" | jq -sRr @uri)
xdg-open "${Search_Engine}${encoded_query}" >/dev/null 2>&1 &
# Segment 4
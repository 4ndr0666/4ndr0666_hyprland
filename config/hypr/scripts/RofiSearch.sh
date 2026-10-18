#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# For Searching via web browsers
set -Eeuo pipefail

config_file="$HOME/.config/hypr/UserConfigs/01-UserDefaults.lua"

if ! command -v jq >/dev/null 2>&1; then
    notify-send -u low "Rofi Search" "jq is required for URL encoding. Please install jq."
    exit 1
fi

if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file not found!"
    exit 1
fi

# Read only the literal local search_engine assignment from the Lua defaults file.
# Never execute the Lua source as shell code.
read_lua_search_engine() {
    awk '
        $0 ~ "^[[:space:]]*local[[:space:]]+search_engine[[:space:]]*=[[:space:]]*\"" {
            line = $0
            sub("^[[:space:]]*local[[:space:]]+search_engine[[:space:]]*=[[:space:]]*\"", "", line)
            sub("\"[[:space:]]*(--.*)?$", "", line)
            print line
            exit
        }
    ' "$config_file"
}

Search_Engine="$(read_lua_search_engine)"
[[ -n "$Search_Engine" && "$Search_Engine" =~ ^https?://[^[:space:]]+$ ]] || {
    printf '%s\n' 'Error: $Search_Engine must be a non-empty HTTP(S) URL.' >&2
    exit 1
}

command -v rofi >/dev/null 2>&1 || {
    printf '%s\n' 'Error: rofi executable not found.' >&2
    exit 1
}
command -v xdg-open >/dev/null 2>&1 || {
    printf '%s\n' 'Error: xdg-open executable not found.' >&2
    exit 1
}

# Rofi theme and message
rofi_theme="$HOME/.config/rofi/config-search.rasi"
msg='Search using the configured web browser'

# Kill Rofi if already running before execution
if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

# Open Rofi and pass the selected query to xdg-open for the configured search engine
query=$(printf '' | rofi -dmenu -config "$rofi_theme" -mesg "$msg")

if [[ -z "$query" ]]; then
    exit 0
fi

encoded_query=$(printf '%s' "$query" | jq -sRr @uri)
xdg-open "${Search_Engine}${encoded_query}" >/dev/null 2>&1 &

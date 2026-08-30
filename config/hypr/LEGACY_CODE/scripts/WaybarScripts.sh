#!/usr/bin/env bash
# /* ---- 💫 https://github.com/4ndr0666 💫 ---- */  #

config_file="$HOME/.config/hypr/UserConfigs/01-UserDefaults.lua"

if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file not found!" >&2
    exit 1
fi

term=$(grep -E '^\s*local\s+term\s*=' "$config_file" | sed -E 's/.*=\s*"([^"]*)".*/\1/')
files=$(grep -E '^\s*local\s+files\s*=' "$config_file" | sed -E 's/.*=\s*"([^"]*)".*/\1/')

[[ -z "$term" ]] && term="kitty"
[[ -z "$files" ]] && files="thunar"

launch_files() {
    if [[ -z "$files" ]]; then
        notify-send -u low -i "$HOME/.config/mako/images/error.png" "Waybar: files" "Set files in 01-UserDefaults.lua or install a default file manager."
        return 1
    fi
    $files &
}

if [[ "$1" == "--btop" ]]; then
    $term --title btop sh -c 'btop'
elif [[ "$1" == "--nvtop" ]]; then
    $term --title nvtop sh -c 'nvtop'
elif [[ "$1" == "--nmtui" ]]; then
    $term -e nmtui
elif [[ "$1" == "--term" ]]; then
    $term &
elif [[ "$1" == "--files" ]]; then
    launch_files
else
    echo "Usage: $0 [--btop | --nvtop | --nmtui | --term | --files]"
fi
# Segment 3
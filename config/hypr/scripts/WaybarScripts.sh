#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  #
set -Eeuo pipefail

config_file="$HOME/.config/hypr/UserConfigs/01-UserDefaults.lua"

if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file not found!"
    exit 1
fi

# Read only literal local command assignments from the Lua defaults file.
# Never execute the Lua source as shell code.
read_lua_command() {
    local name="$1"
    awk -v name="$name" '
        $0 ~ "^[[:space:]]*local[[:space:]]+" name "[[:space:]]*=[[:space:]]*\"" {
            line = $0
            sub("^[[:space:]]*local[[:space:]]+" name "[[:space:]]*=[[:space:]]*\"", "", line)
            sub("\"[[:space:]]*(--.*)?$", "", line)
            print line
            exit
        }
    ' "$config_file"
}

validate_command_name() {
    local name="$1"
    local value="$2"
    [[ -n "$value" && "$value" =~ ^[[:alnum:]_./+-]+$ ]] || {
        printf 'Error: %s must be a single executable name or path.\n' "$name" >&2
        return 1
    }
}

term="$(read_lua_command term)"
files="$(read_lua_command files)"
validate_command_name '\$term' "$term"
validate_command_name '\$files' "$files"

command -v "$term" >/dev/null 2>&1 || {
    printf 'Error: terminal executable not found: %s\n' "$term" >&2
    exit 1
}
command -v "$files" >/dev/null 2>&1 || {
    printf 'Error: file manager executable not found: %s\n' "$files" >&2
    exit 1
}

launch_files() {
    "$files" &
}

if [[ "${1:-}" == "--btop" ]]; then
    "$term" --title btop sh -c 'btop'
elif [[ "${1:-}" == "--nvtop" ]]; then
    "$term" --title nvtop sh -c 'nvtop'
elif [[ "${1:-}" == "--nmtui" ]]; then
    "$term" nmtui
elif [[ "${1:-}" == "--term" ]]; then
    "$term" &
elif [[ "${1:-}" == "--files" ]]; then
    launch_files
else
    echo "Usage: $0 [--btop | --nvtop | --nmtui | --term | --files]"
    echo "--btop       : Open btop in a new term"
    echo "--nvtop      : Open nvtop in a new term"
    echo "--nmtui      : Open nmtui in a new term"
    echo "--term       : Launch a term window"
    echo "--files      : Launch a file manager"
fi

#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib_copy.sh"
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT
export HOME="$test_home/home"
mkdir -p "$HOME/.config/hypr/Monitor_Profiles" "$HOME/.config/hypr/animations" "$test_home/backup/Monitor_Profiles" "$test_home/backup/animations"
printf 'personal-monitor\n' > "$test_home/backup/monitors.lua"
printf 'personal-workspaces\n' > "$test_home/backup/workspaces.lua"
printf 'personal-profile\n' > "$test_home/backup/Monitor_Profiles/custom.lua"
printf 'personal-animation\n' > "$test_home/backup/animations/custom.lua"
LAST_HYPR_BACKUP_PATH="$test_home/backup"
restore_hypr_assets "$test_home/log" 1
cmp "$test_home/backup/monitors.lua" "$HOME/.config/hypr/monitors.lua"
cmp "$test_home/backup/workspaces.lua" "$HOME/.config/hypr/workspaces.lua"
cmp "$test_home/backup/Monitor_Profiles/custom.lua" "$HOME/.config/hypr/Monitor_Profiles/custom.lua"
cmp "$test_home/backup/animations/custom.lua" "$HOME/.config/hypr/animations/custom.lua"
LAST_HYPR_BACKUP_PATH=''
restore_hypr_assets "$test_home/log" 1

#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib_backup.sh"
source "$ROOT/scripts/lib_copy.sh"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home"
dir="$HOME/.config/hypr"
mkdir -p "$dir/UserConfigs" "$tmp/old/UserConfigs/nested"
printf default > "$dir/UserConfigs/new.lua"
printf default > "$dir/UserConfigs/custom.lua"
printf personal > "$tmp/old/UserConfigs/custom.lua"
printf legacy > "$tmp/old/UserConfigs/nested/legacy.conf"
ln -s custom.lua "$tmp/old/UserConfigs/link"
LAST_HYPR_BACKUP_PATH="$tmp/old"
restore_user_configs "$tmp/log" 1 2.3.20
[[ $(cat "$dir/UserConfigs/custom.lua") == personal ]]
[[ $(cat "$dir/UserConfigs/new.lua") == default ]]
[[ $(cat "$dir/UserConfigs/nested/legacy.conf") == legacy ]]
[[ $(readlink "$dir/UserConfigs/link") == custom.lua ]]
grep -Fq 'not loaded by the Lua runtime' "$tmp/log"

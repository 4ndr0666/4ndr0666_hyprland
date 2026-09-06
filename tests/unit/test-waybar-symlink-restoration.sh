#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/scripts/lib_copy.sh"

bash -n "$LIB"

workdir="$(mktemp -d)"
trap 'rm -rf -- "$workdir"' EXIT

export HOME="$workdir/home"
mkdir -p -- "$HOME/.config/waybar" "$workdir/backup/targets" "$workdir/caller"
printf 'old-config\n' >"$HOME/.config/waybar/config"
printf 'relative-config\n' >"$workdir/backup/targets/config"
ln -s -- targets/config "$workdir/backup/config"
printf 'old-style\n' >"$HOME/.config/waybar/style.css"
printf 'absolute-style\n' >"$workdir/backup/absolute-style.css"
ln -s -- "$workdir/backup/absolute-style.css" "$workdir/backup/style.css"

export TEST_BACKUP="$workdir/backup"
replace_dir_transaction() {
  local source="$1"
  local target="$2"
  local log="$3"
  : "$source" "$log"
  rm -rf -- "$target"
  mkdir -p -- "$target"
  printf '%s\n' "$TEST_BACKUP"
}

# shellcheck source=/dev/null
source "$LIB"

cd -- "$workdir/caller"
printf 'y\n' | copy_waybar "$workdir/waybar.log" >/dev/null

[[ -f "$HOME/.config/waybar/config" ]]
[[ "$(cat "$HOME/.config/waybar/config")" == 'relative-config' ]]
[[ -f "$HOME/.config/waybar/style.css" ]]
[[ "$(cat "$HOME/.config/waybar/style.css")" == 'absolute-style' ]]

printf '[PASS] Waybar restoration resolves relative symlink targets from the backup symlink directory and preserves absolute targets.\n'

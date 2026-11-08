#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[[ ! -e "$ROOT/config/hypr/scripts/DarkLight.sh" ]]
if rg -n 'DarkLight\.sh|custom/light_dark|custom-light_dark|\.theme_mode|Switch Dark-Light' "$ROOT/config"; then
  printf '%s\n' 'FAIL: dark/light entry point remains' >&2
  exit 1
fi
[[ -x "$ROOT/config/hypr/scripts/Hyprsunset.sh" ]]
[[ -x "$ROOT/config/hypr/scripts/ThemeChanger.sh" ]]
[[ -x "$ROOT/config/hypr/scripts/WaybarStyles.sh" ]]
[[ -x "$ROOT/config/hypr/UserScripts/WallpaperSelect.sh" ]]
grep -Fq 'custom/nightlight' "$ROOT/config/waybar/ModulesCustom"

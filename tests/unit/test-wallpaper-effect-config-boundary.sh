#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/config/hypr/UserScripts/WallpaperEffects.sh"

! grep -Fq 'eval ' "$FILE"
grep -Fq 'case "$choice" in' "$FILE"
grep -Fq 'magick "$wallpaper_current"' "$FILE"
grep -Fq '"$wallpaper_output"' "$FILE"
grep -Fq 'AWWW_PARAMS=(' "$FILE"
grep -Fq '"${AWWW_PARAMS[@]}"' "$FILE"

if grep -Eq 'effects\[[^]]+\]=.*\$wallpaper_(current|output)' "$FILE"; then
  printf '%s\n' 'command-string effect table remains' >&2
  exit 1
fi

printf '%s\n' 'Wallpaper effect config execution boundary: PASS'

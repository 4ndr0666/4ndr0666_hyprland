#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GAMEMODE="$ROOT/config/hypr/scripts/GameMode.sh"

[[ -f "$GAMEMODE" ]]

grep -Fq 'set -Eeuo pipefail' "$GAMEMODE"
grep -Fq 'current_wallpaper="$HOME/.config/rofi/.current_wallpaper"' "$GAMEMODE"
grep -Fq '[[ -f "$current_wallpaper" ]]' "$GAMEMODE"
grep -Fq 'awww img "$current_wallpaper"' "$GAMEMODE"
grep -Fq '"$SCRIPTSDIR/WallustAwww.sh" "$current_wallpaper"' "$GAMEMODE"
! grep -Fq 'WallustSwww.sh' "$GAMEMODE"
! grep -Fq 'wallust run -s' "$GAMEMODE"

printf '%s\n' 'GameMode Wallust boundary: PASS'

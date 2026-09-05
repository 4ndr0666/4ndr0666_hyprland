#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WALLUST_SCRIPT="$ROOT/config/hypr/scripts/WallustAwww.sh"
INITIAL_BOOT="$ROOT/config/hypr/initial-boot.sh"
RANDOM_WALLPAPER="$ROOT/config/hypr/UserScripts/WallpaperRandom.sh"
AUTO_CHANGE="$ROOT/config/hypr/UserScripts/WallpaperAutoChange.sh"
REFRESH_NO_WAYBAR="$ROOT/config/hypr/scripts/RefreshNoWaybar.sh"
DARK_LIGHT="$ROOT/config/hypr/scripts/DarkLight.sh"

for file in "$WALLUST_SCRIPT" "$INITIAL_BOOT" "$RANDOM_WALLPAPER" "$AUTO_CHANGE" "$REFRESH_NO_WAYBAR" "$DARK_LIGHT"; do
  [[ -f "$file" ]] || { printf '%s\n' "Missing Wallust orchestration file: $file" >&2; exit 1; }
done

# WallustAwww.sh is the sole palette-generation boundary.
! grep -Fq 'wallust run -s' "$INITIAL_BOOT"
! grep -Fq 'wallust run -s' "$RANDOM_WALLPAPER"
! grep -Fq 'wallust run -s' "$AUTO_CHANGE"
! grep -Fq 'WallustSwww.sh' "$REFRESH_NO_WAYBAR"
! grep -Fq 'WallustSwww.sh' "$DARK_LIGHT"

# Callers must invoke the canonical generator exactly through an executable path.
grep -Eq '^[[:space:]]*"\$[^"[:space:]]+/WallustAwww\.sh"[[:space:]]+' "$INITIAL_BOOT"
grep -Eq '^[[:space:]]*"\$[^"[:space:]]+/WallustAwww\.sh"[[:space:]]+' "$RANDOM_WALLPAPER"
grep -Eq '^[[:space:]]*"\$[^"[:space:]]+/WallustAwww\.sh"[[:space:]]+' "$AUTO_CHANGE"
grep -Eq '^[[:space:]]*"\$[^"[:space:]]+/WallustAwww\.sh"[[:space:]]+' "$DARK_LIGHT"

# Random wallpaper selection must preserve paths containing whitespace.
grep -Fq 'mapfile -d' "$RANDOM_WALLPAPER"
grep -Fq '"${AWWW_PARAMS[@]}"' "$RANDOM_WALLPAPER"

# The non-Waybar refresh must not regenerate or reload the Wallust palette.
! grep -Fq 'WallustAwww.sh' "$REFRESH_NO_WAYBAR"

# Generated consumer reload remains fail-closed at the canonical boundary.
grep -Fq 'if ! wallust run -s "$wallpaper_path"; then' "$WALLUST_SCRIPT"
grep -Fq '[ERROR] Wallust failed; consumers will not be reloaded.' "$WALLUST_SCRIPT"
grep -Fq 'validate_target "$waybar_colors"' "$WALLUST_SCRIPT"
grep -Fq 'waybar-msg cmd reload' "$WALLUST_SCRIPT"

printf '%s\n' 'Waybar/Wallust orchestration boundary: PASS'

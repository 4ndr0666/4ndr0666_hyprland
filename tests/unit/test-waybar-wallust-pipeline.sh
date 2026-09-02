#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WALLUST_SCRIPT="$ROOT/config/hypr/scripts/WallustAwww.sh"
SIMPLE_STYLE="$ROOT/config/waybar/style/[Wallust] Simple.css"

[[ -f "$WALLUST_SCRIPT" ]]
[[ -f "$SIMPLE_STYLE" ]]

grep -Fq 'if ! wallust run -s "$wallpaper_path"; then' "$WALLUST_SCRIPT"
grep -Fq '[ERROR] Wallust failed; consumers will not be reloaded.' "$WALLUST_SCRIPT"
grep -Fq 'validate_target "$waybar_colors"' "$WALLUST_SCRIPT"
grep -Fq 'validate_target "$rofi_colors"' "$WALLUST_SCRIPT"
grep -Fq 'Wallust Waybar palette failed structural validation.' "$WALLUST_SCRIPT"
! grep -Fq 'wallust run -s "$wallpaper_path" || true' "$WALLUST_SCRIPT"
! grep -Fq 'wait_for_templates' "$WALLUST_SCRIPT"

grep -Fq "@import '../wallust/colors-waybar.css';" "$SIMPLE_STYLE"
! grep -Fq "@import '../../.config/waybar/wallust/colors-waybar.css';" "$SIMPLE_STYLE"

printf '%s\n' 'Waybar/Wallust palette pipeline boundary: PASS'

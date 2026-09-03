#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WALLUST_SCRIPT="$ROOT/config/hypr/scripts/WallustAwww.sh"
WAYBAR_STYLE_DIR="$ROOT/config/waybar/style"
WLOGOUT_STYLE="$ROOT/config/wlogout/style.css"
SWAYNC_STYLE="$ROOT/config/swaync/style.css"

[[ -f "$WALLUST_SCRIPT" ]]
[[ -d "$WAYBAR_STYLE_DIR" ]]
[[ -f "$WLOGOUT_STYLE" ]]
[[ -f "$SWAYNC_STYLE" ]]

grep -Fq 'if ! wallust run -s "$wallpaper_path"; then' "$WALLUST_SCRIPT"
grep -Fq '[ERROR] Wallust failed; consumers will not be reloaded.' "$WALLUST_SCRIPT"
grep -Fq 'validate_target "$waybar_colors"' "$WALLUST_SCRIPT"
grep -Fq 'validate_target "$rofi_colors"' "$WALLUST_SCRIPT"
grep -Fq 'Wallust Waybar palette failed structural validation.' "$WALLUST_SCRIPT"
! grep -Fq 'wallust run -s "$wallpaper_path" || true' "$WALLUST_SCRIPT"
! grep -Fq 'wait_for_templates' "$WALLUST_SCRIPT"

wallust_style_count=0
for style in "$WAYBAR_STYLE_DIR"/*.css "$WAYBAR_STYLE_DIR"/*/*.css; do
    [[ -f "$style" ]] || continue
    if grep -Fq 'colors-waybar.css' "$style"; then
        wallust_style_count=$((wallust_style_count + 1))
        ! grep -Fq '../../.config/waybar/wallust/colors-waybar.css' "$style"
        style_dir="$(dirname "$style")"
        if [[ "$style_dir" == "$WAYBAR_STYLE_DIR" ]]; then
            grep -Fq '../wallust/colors-waybar.css' "$style"
        else
            grep -Fq '../../wallust/colors-waybar.css' "$style"
        fi
    fi
done

[[ "$wallust_style_count" -gt 0 ]]

grep -Fq "../../.config/waybar/wallust/colors-waybar.css" "$WLOGOUT_STYLE"
grep -Fq "../../.config/waybar/wallust/colors-waybar.css" "$SWAYNC_STYLE"

printf '%s\n' "Waybar/Wallust palette pipeline boundary: PASS ($wallust_style_count Waybar styles)"

#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$tmp/bin" "$HOME/.config/hypr/wallpaper_effects" "$HOME/.config/waybar/wallust" "$HOME/.config/rofi/wallust"
printf image > "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
printf '@define-color color0 #123456;\n' > "$HOME/.config/waybar/wallust/colors-waybar.css"
printf 'color12: #123456;\n' > "$HOME/.config/rofi/wallust/colors-rofi.rasi"
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/wallust"
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/waybar-msg"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
bash "$ROOT/config/hypr/scripts/WallustAwww.sh" "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
[[ $(cat "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current") == image ]]
printf replacement > "$tmp/other"
bash "$ROOT/config/hypr/scripts/WallustAwww.sh" "$tmp/other"
[[ $(cat "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current") == replacement ]]

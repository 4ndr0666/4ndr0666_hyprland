#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Final checking if packages are installed
# NOTE: These package check are only the essentials

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
cd "$ROOT"
LOG="Install-Logs/00_CHECK-$(date +%d-%H%M%S)_installed.log"
mkdir -p "$(dirname "$LOG")"
source "$SCRIPT_DIR/core/packages.sh"

packages=(cliphist kvantum rofi-wayland imagemagick swaync swww wallust waybar wl-clipboard wlogout kitty hypridle hyprlock hyprland)
missing=()
for pkg in "${packages[@]}"; do package_is_installed "$pkg" || missing+=("$pkg"); done
if ((${#missing[@]} == 0)); then
  printf '[OK] All essential packages are installed.\n' | tee -a "$LOG"
else
  printf '[WARN] Missing packages:\n' | tee -a "$LOG"
  printf '%s\n' "${missing[@]}" | tee -a "$LOG"
fi

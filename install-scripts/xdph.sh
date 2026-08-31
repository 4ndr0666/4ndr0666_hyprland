#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# XDG-Desktop-Portals hyprland #


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_xdph.log"
mkdir -p "$(dirname "$LOG")"
export LOG

source "$SCRIPT_DIR/core/packages.sh"

XDG_PORTAL_PACKAGES=(
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
  umockdev
)

printf '%s\n' "[INFO] Installing XDG desktop portal packages."
package_install "${XDG_PORTAL_PACKAGES[@]}"
printf '%s\n' "[OK] XDG desktop portal package transaction completed."

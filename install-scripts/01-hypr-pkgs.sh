#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Canonical Hyprland runtime package manifest.
# Every package listed here is an intentional installer-owned runtime input.
# Feature-specific applications belong to their own opt-in installer modules.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_hypr-pkgs.log"
mkdir -p "$(dirname "$LOG")"
export LOG

# This is the baseline desktop package set. Keep it minimal: package-manager
# dependencies may expand the transaction, but no convenience application is
# admitted here merely because it was present in the legacy installer.
CORE_PACKAGES=(
  bc
  cliphist
  curl
  grim
  gvfs
  gvfs-mtp
  hyprpolkitagent
  imagemagick
  jq
  kitty
  kvantum
  libspng
  network-manager-applet
  pamixer
  pavucontrol
  playerctl
  python-requests
  python-pyquery
  qt5ct
  qt6ct
  qt6-svg
  rofi
  slurp
  swappy
  swaync
  waybar
  wl-clipboard
  wlogout
  xdg-user-dirs
  xdg-utils
  yad
)

# These packages are deliberately explicit AUR inputs. The installer must
# never silently reinterpret an unavailable official package as an AUR package.
AUR_PACKAGES=(
  swww
  wallust
)

source "$SCRIPT_DIR/core/packages.sh"

package_install "${CORE_PACKAGES[@]}"
package_install_aur "${AUR_PACKAGES[@]}"

printf '%s\n' "[OK] Hyprland package transactions completed."
printf '%s\n' "[INFO] Installer-owned package manifest: ${PACKAGE_MANIFEST}"

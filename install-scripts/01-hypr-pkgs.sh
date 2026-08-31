#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Hyprland Packages #

# edit your packages desired here. 
# WARNING! If you remove packages here, dotfiles may not work properly.
# and also, ensure that packages are present in AUR and official Arch Repo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_hypr-pkgs.log"
mkdir -p "$(dirname "$LOG")"

# Package intent is kept here; transaction and ownership semantics live in
# core/packages.sh. Do not add package-manager commands to this file.
CORE_PACKAGES=(
  bc
  cliphist
  curl
  grim
  gvfs
  gvfs-mtp
  hyprpolkitagent
  imagemagick
  inxi
  jq
  kitty
  kvantum
  libspng
  nano
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
  unzip
  waybar
  wget
  wl-clipboard
  wlogout
  xdg-user-dirs
  xdg-utils
  yad
)

OPTIONAL_PACKAGES=(
  brightnessctl
  btop
  cava
  loupe
  fastfetch
  gnome-system-monitor
  mousepad
  mpv
  mpv-mpris
  nvtop
  nwg-look
  nwg-displays
  pacman-contrib
  qalculate-gtk
  yt-dlp
)

# These names are intentionally explicit AUR inputs. The installer must never
# silently reinterpret an unavailable official package as an AUR package.
AUR_PACKAGES=(
  swww
  wallust
)

source "$SCRIPT_DIR/core/packages.sh"

package_install "${CORE_PACKAGES[@]}" "${OPTIONAL_PACKAGES[@]}"
package_install_aur "${AUR_PACKAGES[@]}"

printf '%s\n' "[OK] Hyprland package transactions completed."
printf '%s\n' "[INFO] Installer-owned package manifest: ${PACKAGE_MANIFEST}"

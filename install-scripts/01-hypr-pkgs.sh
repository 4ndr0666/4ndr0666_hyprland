#!/bin/bash
# === 4ndr0666 === #
# Hyprland package specification.

set -Eeuo pipefail

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
  swww
  unzip
  wallust
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

EXTRA_PACKAGES=()

# Formerly this script unconditionally removed packages such as rofi,
# wallust-git, dunst and mako. That destroyed pre-existing system state and
# was not reversible. Conflicts are now left to the package transaction and
# will fail loudly until a deliberate replacement policy is implemented.

source "$SCRIPT_DIR/core/packages.sh"

package_install "${CORE_PACKAGES[@]}" "${OPTIONAL_PACKAGES[@]}" "${EXTRA_PACKAGES[@]}"

printf '%s\n' "[OK] Hyprland package transaction completed."
printf '%s\n' "[INFO] Installer-owned package manifest: ${PACKAGE_MANIFEST}"

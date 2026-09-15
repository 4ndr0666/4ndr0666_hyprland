#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
cd "$ROOT_DIR"

LOG="${LOG:-Install-Logs/install-$(date +%d-%H%M%S)_final-check.log}"
mkdir -p "$(dirname "$LOG")"
source "$SCRIPT_DIR/core/packages.sh"

# Final-check mirrors the canonical installer-owned baseline. Feature-specific
# modules must own and verify their own package contracts.
packages=(
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
  awww
  wallust
  waybar
  wl-clipboard
  wlogout
  xdg-user-dirs
  xdg-utils
  yad
  hypridle
  hyprlock
  hyprland
  pipewire
  wireplumber
  pipewire-audio
  pipewire-alsa
  pipewire-pulse
  sof-firmware
  adobe-source-code-pro-fonts
  noto-fonts-emoji
  otf-font-awesome
  ttf-droid
  ttf-fira-code
  ttf-fantasque-nerd
  ttf-jetbrains-mono
  ttf-jetbrains-mono-nerd
  ttf-victor-mono
  noto-fonts
)

missing=()
for pkg in "${packages[@]}"; do
  package_is_installed "$pkg" || missing+=("$pkg")
done

if ((${#missing[@]} == 0)); then
  printf '%s\n' '[OK] Canonical baseline package verification passed.' | tee -a "$LOG"
  exit 0
fi

printf '[ERROR] Missing canonical baseline packages: %s\n' "${missing[*]}" | tee -a "$LOG" >&2
exit 1

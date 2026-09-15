#!/bin/bash
# Canonical package ownership manifest for the mandatory installation path.
# Feature-specific modules remain responsible for their own opt-in packages.

BASE_PACKAGES=(
  base-devel
  archlinux-keyring
  findutils
)

INSTALLER_RUNTIME_PACKAGES=(
  libnewt
  pciutils
)

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

AUR_PACKAGES=(
  awww
  wallust
)

PIPEWIRE_PACKAGES=(
  pipewire
  wireplumber
  pipewire-audio
  pipewire-alsa
  pipewire-pulse
  sof-firmware
)

HYPRLAND_PACKAGES=(
  hyprland
  hypridle
  hyprlock
)

FONT_PACKAGES=(
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

CANONICAL_BASELINE_PACKAGES=(
  "${BASE_PACKAGES[@]}"
  "${INSTALLER_RUNTIME_PACKAGES[@]}"
  "${CORE_PACKAGES[@]}"
  "${PIPEWIRE_PACKAGES[@]}"
  "${HYPRLAND_PACKAGES[@]}"
  "${FONT_PACKAGES[@]}"
)

CANONICAL_BASELINE_AUR_PACKAGES=(
  "${AUR_PACKAGES[@]}"
)

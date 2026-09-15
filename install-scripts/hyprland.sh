#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Main Hyprland Package #

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_hyprland.log"
mkdir -p "$(dirname "$LOG")"
export LOG

source "$SCRIPT_DIR/core/package-manifest.sh"
source "$SCRIPT_DIR/core/packages.sh"

if command -v Hyprland >/dev/null 2>&1; then
  printf '[NOTE] Hyprland is already installed. No action required.\n'
else
  printf '[INFO] Hyprland not found. Installing Hyprland...\n'
  package_install "${HYPRLAND_PACKAGES[0]}"
fi

printf '[INFO] Installing other Hyprland-eco packages...\n'
for HYPR in "${HYPRLAND_PACKAGES[@]:1}"; do
  if ! command -v "$HYPR" >/dev/null 2>&1; then
    printf '[INFO] %s not found. Installing...\n' "$HYPR"
    package_install "$HYPR"
  else
    printf '[NOTE] %s is already installed. No action required.\n' "$HYPR"
  fi
done

printf '\n%.0s' {1..2}

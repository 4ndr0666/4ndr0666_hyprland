#!/bin/bash
# === 4ndr0666 === #
# Asus ROG Laptops #

set -Eeuo pipefail

rog=(
  power-profiles-daemon
  asusctl
  supergfxctl
  rog-control-center
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_rog.log"
mkdir -p "$(dirname "$LOG")"
source "$SCRIPT_DIR/core/packages.sh"

printf '[INFO] Installing ASUS ROG packages...\n'
package_install "${rog[@]}"

printf 'Activating ROG services...\n'
sudo systemctl enable supergfxd 2>&1 | tee -a "$LOG"
printf 'Enabling power-profiles-daemon...\n'
sudo systemctl enable power-profiles-daemon 2>&1 | tee -a "$LOG"

printf '\n%.0s' {1..2}

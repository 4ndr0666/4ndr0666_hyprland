#!/bin/bash
# === 4ndr0666 === #
# Bluetooth Stuff #

set -Eeuo pipefail

blue=(
  bluez
  bluez-utils
  blueman
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_bluetooth.log"
mkdir -p "$(dirname "$LOG")"
source "$SCRIPT_DIR/core/packages.sh"

printf '[INFO] Installing Bluetooth packages...\n'
package_install "${blue[@]}"

printf 'Activating Bluetooth services...\n'
sudo systemctl enable --now bluetooth.service 2>&1 | tee -a "$LOG"

printf '\n%.0s' {1..2}

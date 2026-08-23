#!/bin/bash
# === 4ndr0666 === #
# Fonts #

set -Eeuo pipefail

fonts=(
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_fonts.log"
mkdir -p "$(dirname "$LOG")"
source "$SCRIPT_DIR/core/packages.sh"

printf '[INFO] Installing necessary fonts...\n'
package_install "${fonts[@]}"

printf '\n%.0s' {1..2}

#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Fonts #

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_fonts.log"
mkdir -p "$(dirname "$LOG")"
export LOG

source "$SCRIPT_DIR/core/package-manifest.sh"
source "$SCRIPT_DIR/core/packages.sh"

printf '[INFO] Installing necessary fonts...\n'
package_install "${FONT_PACKAGES[@]}"

printf '\n%.0s' {1..2}

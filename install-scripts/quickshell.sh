#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# quickshell - for desktop overview replacing AGS


if [[ ${USE_PRESET:-} = [Yy] ]]; then
  source ./preset.sh
fi

quick=(
  qt6-5compat
  quickshell
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_quick.log"
mkdir -p "$(dirname "$LOG")"
source "$SCRIPT_DIR/core/packages.sh"

printf '[INFO] Installing Quick Shell for Desktop Overview...\n'
package_install "${quick[@]}"

printf '\n%.0s' {1..1}

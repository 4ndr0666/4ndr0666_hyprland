#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Paru AUR Helper #
# NOTE: If yay is already installed, paru will not be installed #


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
cd "$ROOT"

LOG="${LOG:-Install-Logs/install-$(date +%d-%H%M%S)_paru.log}"
mkdir -p "$(dirname "$LOG")"
export LOG

source "$SCRIPT_DIR/core/aur-bootstrap.sh"

if command -v paru >/dev/null 2>&1; then
  printf '[INFO] paru is already installed.\n' | tee -a "$LOG"
  exit 0
fi

printf '[INFO] Bootstrapping paru-bin from the AUR.\n' | tee -a "$LOG"
package_bootstrap_aur_helper paru-bin
printf '[OK] AUR helper bootstrap completed.\n' | tee -a "$LOG"

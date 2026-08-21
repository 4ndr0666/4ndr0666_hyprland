#!/bin/bash
# Bootstrap yay only. Normal AUR package transactions belong to core/packages.sh.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
cd "$ROOT"

LOG="${LOG:-Install-Logs/install-$(date +%d-%H%M%S)_yay.log}"
mkdir -p "$(dirname "$LOG")"
export LOG

source "$SCRIPT_DIR/core/aur-bootstrap.sh"

if command -v yay >/dev/null 2>&1; then
  printf '[INFO] yay is already installed.\n' | tee -a "$LOG"
  exit 0
fi

printf '[INFO] Bootstrapping yay-bin from the AUR.\n' | tee -a "$LOG"
package_bootstrap_aur_helper yay-bin
printf '[OK] AUR helper bootstrap completed.\n' | tee -a "$LOG"

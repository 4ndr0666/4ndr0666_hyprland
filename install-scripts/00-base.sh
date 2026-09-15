#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Base installation prerequisites.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_base.log"
mkdir -p "$(dirname "$LOG")"
export LOG

source "$SCRIPT_DIR/core/package-manifest.sh"
source "$SCRIPT_DIR/core/packages.sh"

printf '%s\n' "[INFO] Installing base development packages."
package_install "${BASE_PACKAGES[@]}"
printf '%s\n' "[OK] Base package transaction completed."

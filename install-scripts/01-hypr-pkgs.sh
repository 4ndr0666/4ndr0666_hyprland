#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Canonical Hyprland runtime package installation.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_hypr-pkgs.log"
mkdir -p "$(dirname "$LOG")"
export LOG

source "$SCRIPT_DIR/core/package-manifest.sh"
source "$SCRIPT_DIR/core/packages.sh"

package_install "${CORE_PACKAGES[@]}"
package_install_aur "${AUR_PACKAGES[@]}"

printf '%s\n' "[OK] Hyprland package transactions completed."
printf '%s\n' "[INFO] Installer-owned package manifest: ${PACKAGE_MANIFEST}"

#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# GTK Themes & ICONS and  Sourcing from a different Repo #

engine=(
  unzip
  gtk-engine-murrine
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_themes.log"
mkdir -p "$(dirname "$LOG")"
source "$SCRIPT_DIR/core/packages.sh"

package_install "${engine[@]}"

if [ -d "GTK-themes-icons" ]; then
  echo "[NOTE] GTK themes and Icons directory exist..deleting..." 2>&1 | tee -a "$LOG"
  rm -rf "GTK-themes-icons" 2>&1 | tee -a "$LOG"
fi

echo "[NOTE] Cloning GTK themes and Icons repository..." 2>&1 | tee -a "$LOG"
if git clone --depth=1 https://github.com/4ndr0666/GTK-themes-icons.git; then
  cd GTK-themes-icons
  chmod +x auto-extract.sh
  ./auto-extract.sh
  cd ..
  echo "[OK] Extracted GTK Themes & Icons to ~/.icons & ~/.themes directories" 2>&1 | tee -a "$LOG"
else
  echo "[ERROR] Download failed for GTK themes and Icons.." 2>&1 | tee -a "$LOG"
fi

printf '\n%.0s' {1..2}

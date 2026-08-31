#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Thunar #

thunar=(
  thunar
  thunar-volman
  tumbler
  ffmpegthumbnailer
  thunar-archive-plugin
  xarchiver
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_thunar.log"
mkdir -p "$(dirname "$LOG")"
source "$SCRIPT_DIR/core/packages.sh"

printf '[INFO] Installing Thunar packages...\n'
package_install "${thunar[@]}"

printf '\n%.0s' {1..1}

for DIR1 in gtk-3.0 Thunar xfce4; do
  DIRPATH="$HOME/.config/$DIR1"
  if [ -d "$DIRPATH" ]; then
    echo "[NOTE] Config for $DIR1 found, no need to copy." 2>&1 | tee -a "$LOG"
  else
    echo "[NOTE] Config for $DIR1 not found, copying from assets." 2>&1 | tee -a "$LOG"
    cp -r "assets/$DIR1" "$HOME/.config/" && echo "[OK] Copy $DIR1 completed!" || echo "[ERROR] Failed to copy $DIR1 config files." 2>&1 | tee -a "$LOG"
  fi
done

printf '\n%.0s' {1..2}

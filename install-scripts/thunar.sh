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
cd -- "$PARENT_DIR" || exit 1

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
    if cp -a -- "assets/$DIR1" "$HOME/.config/"; then
      printf '[OK] Copy %s completed!\n' "$DIR1" | tee -a "$LOG"
    else
      printf '[ERROR] Failed to copy %s config files.\n' "$DIR1" | tee -a "$LOG" >&2
      exit 1
    fi
  fi
done

printf '\n%.0s' {1..2}

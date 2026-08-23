#!/bin/bash
# === 4ndr0666 === #
# pokemon-color-scripts

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_zsh_pokemon.log"
mkdir -p "$(dirname "$LOG")"
source "$SCRIPT_DIR/core/packages.sh"

printf '[INFO] Removing any traces of Pokemon Color Scripts\n'
printf '[INFO] Installing Pokemon Color Scripts\n'
package_install_aur pokemon-colorscripts-git

if [ -f "$HOME/.zshrc" ]; then
  sed -i 's|^#pokemon-colorscripts --no-title -s -r | fastfetch -c \$HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -|pokemon-colorscripts --no-title -s -r | fastfetch -c \$HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -|' "$HOME/.zshrc" >> "$LOG" 2>&1
  echo "[OK] pokemon-colorscripts added to .zshrc" >> "$LOG"
else
  echo "[WARN] ~/.zshrc not found. Please add pokemon-colorscripts manually." >> "$LOG"
fi

printf '\n%.0s' {1..2}

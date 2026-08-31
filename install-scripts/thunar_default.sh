#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Thunar-default #


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core/ui.sh"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_thunar-default.log"

printf "${INFO} Setting ${SKY_BLUE}Thunar${RESET} as default file manager...\n"
xdg-mime default thunar.desktop inode/directory
xdg-mime default thunar.desktop application/x-wayland-gnome-saved-search
echo "${OK} ${MAGENTA}Thunar${RESET} is now set as the default file manager." | tee -a "$LOG"

printf "\n%.0s" {1..2}

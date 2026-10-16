#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Hyprland-Dots to download from main #


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd -- "$PARENT_DIR" || exit 1

NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
SKY_BLUE="$(tput setaf 6)"
RESET="$(tput sgr0)"

printf '%s\n' "${NOTE} Deploying ${SKY_BLUE}4ndr0666's Hyprland Dots${RESET} from local repository...."

if [[ ! -x ./copy.sh ]]; then
  chmod +x ./copy.sh
fi
./copy.sh

printf '\n%.0s' {1..2}

#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Hyprland-Dots to download from main #


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
SKY_BLUE="$(tput setaf 6)"
YELLOW="$(tput setaf 3)"
RESET="$(tput sgr0)"

printf '%s\n' "${NOTE} Deploying ${SKY_BLUE}4ndr0666's Hyprland Dots${RESET} from local repository...."

if [[ ! -x ./copy.sh ]]; then
  chmod +x ./copy.sh
fi
./copy.sh

printf '\n%.0s' {1..2}

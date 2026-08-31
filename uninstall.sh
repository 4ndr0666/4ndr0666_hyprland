#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# KooL Arch-Hyprland uninstall script #

clear

# Set some colors for output messages
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
MAGENTA="$(tput setaf 5)"
ORANGE="$(tput setaf 214)"
WARNING="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
SKY_BLUE="$(tput setaf 6)"
RESET="$(tput sgr0)"


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$SCRIPT_DIR/install-scripts/core/packages.sh"

if [[ ! -r "$CORE" ]]; then
  printf '%s\n' '[ERROR] Package core is unavailable; refusing destructive uninstall.' >&2
  exit 1
fi

source "$CORE"

LOG="$SCRIPT_DIR/Install-Logs/uninstall-$(date +%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG")"

if [[ ! -s "$PACKAGE_MANIFEST" ]]; then
  printf '%s\n' '[INFO] No installer-owned package manifest exists. Nothing to uninstall.'
  exit 0
fi

printf '%s\n' '[ACTION] Removing packages recorded as installer-owned.'
printf '%s\n' "[INFO] Manifest: $PACKAGE_MANIFEST"

if package_remove_owned; then
  printf '%s\n' '[OK] Installer-owned package removal completed.'
else
  printf '%s\n' '[ERROR] Package removal failed; ownership manifest was retained for retry.' >&2
  exit 1
fi

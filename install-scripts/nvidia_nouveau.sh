#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Nvidia Blacklist #


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core/ui.sh"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_nvidia.log"

printf '%s\n' "${INFO} ${SKY_BLUE}blacklist nouveau${RESET}..."
NOUVEAU="/etc/modprobe.d/nouveau.conf"
if [ -f "$NOUVEAU" ]; then
  printf '%s\n' "${OK} Seems like ${YELLOW}nouveau${RESET} is already blacklisted..moving on."
else
  echo "blacklist nouveau" | sudo tee -a "$NOUVEAU" 2>&1 | tee -a "$LOG"

  if [ -f "/etc/modprobe.d/blacklist.conf" ]; then
    echo "install nouveau /bin/true" | sudo tee -a "/etc/modprobe.d/blacklist.conf" 2>&1 | tee -a "$LOG"
  else
    echo "install nouveau /bin/true" | sudo tee "/etc/modprobe.d/blacklist.conf" 2>&1 | tee -a "$LOG"
  fi
fi

printf "\n%.0s" {1..2}

#!/bin/bash
# === 4ndr0666 === #
# Adding users into input group #

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core/ui.sh"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_input.log"

if grep -q '^input:' /etc/group; then
    echo "${OK} ${MAGENTA}input${RESET} group exists."
else
    echo "${NOTE} ${MAGENTA}input${RESET} group doesn't exist. Creating ${MAGENTA}input${RESET} group..."
    sudo groupadd input
    echo "${MAGENTA}input${RESET} group created" >> "$LOG"
fi

sudo usermod -aG input "$(whoami)"
echo "${OK} ${YELLOW}user${RESET} added to the ${MAGENTA}input${RESET} group. Changes will take effect after you log out and log back in." >> "$LOG"

printf "\n%.0s" {1..2}

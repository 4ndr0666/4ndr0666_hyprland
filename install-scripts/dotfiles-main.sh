#!/usr/bin/env bash
# === 4ndr0666 === #
# Dotfiles deployment from local Monorepo.

set -Eeuo pipefail

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

# Post-Install Sanitization Hook for Hyprland 0.56+ Lua IPC Compliance.
printf '%s\n' "${NOTE} Mirroring Hyprland 0.56+ IPC fixes into deployed Waybar target tree..."

TARGET_WAYBAR_DIR="$HOME/.config/waybar"

if [[ -d "$TARGET_WAYBAR_DIR" ]]; then
    find "$TARGET_WAYBAR_DIR" -type f \( -name 'ModulesWorkspaces*' -o -name 'WaybarWorkspaces*' -o -name 'workspace*' \) \
        -exec sed -i 's/"on-click": "activate"/"on-click": "hyprctl dispatch '\''hl.dsp.focus({ workspace = \\"{name}\\" })'\''"/g' {} +

    find "$TARGET_WAYBAR_DIR" -type f \
        -exec sed -i 's/"hyprctl dispatch workspace e+1"/"hyprctl dispatch '\''hl.dsp.focus({ workspace = \\"e+1\\" })'\''"/g' {} +

    find "$TARGET_WAYBAR_DIR" -type f \
        -exec sed -i 's/"hyprctl dispatch workspace e-1"/"hyprctl dispatch '\''hl.dsp.focus({ workspace = \\"e-1\\" })'\''"/g' {} +

    find "$TARGET_WAYBAR_DIR" -type f -name 'ModulesCustom*' \
        -exec sed -i 's/"hyprctl dispatch exit"/"hyprctl dispatch '\''hl.dsp.exit()'\''"/g' {} +

    printf '%s\n' "${OK} Deployed Waybar tree fully sanitized for Hyprland 0.56+."
else
    printf '%s\n' "${WARN} $TARGET_WAYBAR_DIR not found. Skipping IPC patch."
fi

printf '\n%.0s' {1..2}

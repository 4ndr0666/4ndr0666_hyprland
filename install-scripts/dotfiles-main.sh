#!/bin/bash
# === 4ndr0666 === #
# Dotfiles deployment from local Monorepo #

## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change the working directory to the parent directory of the script (Repo Root)
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Failed to change directory to $PARENT_DIR"; exit 1; }

# Source the global functions script
if ! source "$SCRIPT_DIR/Global_functions.sh"; then
  echo "Failed to source Global_functions.sh"
  exit 1
fi

printf "${NOTE} Deploying ${SKY_BLUE}4ndr0666's Hyprland Dots${RESET} from local repository....\n"

# In a monorepo, copy.sh is in the root directory
if [ -f "copy.sh" ]; then
  chmod +x copy.sh
  ./copy.sh
else
  echo -e "$ERROR Local ${YELLOW}copy.sh${RESET} not found in the repository root. Ensure you have the complete monorepo."
  exit 1
fi

# ==============================================================================
# Post-Install Sanitization Hook for Hyprland 0.56+ Lua IPC Compliance
# ==============================================================================
printf "${NOTE} Mirroring Hyprland 0.56+ IPC fixes into deployed Waybar target tree...\n"

TARGET_WAYBAR_DIR="$HOME/.config/waybar"

if [ -d "$TARGET_WAYBAR_DIR" ]; then
    # 1. Patch workspace clicks (Replaces deprecated "activate" string)
    find "$TARGET_WAYBAR_DIR" -type f \( -name "ModulesWorkspaces*" -o -name "WaybarWorkspaces*" -o -name "workspace*" \) \
        -exec sed -i 's/"on-click": "activate"/"on-click": "hyprctl dispatch '\''hl.dsp.focus({ workspace = \\"{name}\\" })'\''"/g' {} +

    # 2. Patch workspace scroll handlers
    find "$TARGET_WAYBAR_DIR" -type f \
        -exec sed -i 's/"hyprctl dispatch workspace e+1"/"hyprctl dispatch '\''hl.dsp.focus({ workspace = \\"e+1\\" })'\''"/g' {} +
    find "$TARGET_WAYBAR_DIR" -type f \
        -exec sed -i 's/"hyprctl dispatch workspace e-1"/"hyprctl dispatch '\''hl.dsp.focus({ workspace = \\"e-1\\" })'\''"/g' {} +

    # 3. Patch custom quit module
    find "$TARGET_WAYBAR_DIR" -type f -name "ModulesCustom*" \
        -exec sed -i 's/"hyprctl dispatch exit"/"hyprctl dispatch '\''hl.dsp.exit()'\''"/g' {} +

    printf "${OK} Deployed Waybar tree fully sanitized for Hyprland 0.56+.\n"
else
    printf "${WARN} $TARGET_WAYBAR_DIR not found. Skipping IPC patch.\n"
fi

printf "\n%.0s" {1..2}
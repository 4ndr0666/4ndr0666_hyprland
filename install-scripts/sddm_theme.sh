#!/bin/bash
# === 4ndr0666 === #
# SDDM themes #

source_theme="https://github.com/4ndr0666/simple-sddm-2.git"
theme_name="simple_sddm_2"

## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change the working directory to the parent directory of the script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Failed to change directory to $PARENT_DIR"; exit 1; }

# Source the global functions script
if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Failed to source Global_functions.sh"
  exit 1
fi


# Set the name of the log file to include the current date and time
LOG="Install-Logs/install-$(date +%d-%H%M%S)_sddm_theme.log"
    
# SDDM-themes
printf "${INFO} Installing ${SKY_BLUE}Additional SDDM Theme${RESET}\n"

# Check if /usr/share/sddm/themes/$theme_name exists and remove if it does
if [ -d "/usr/share/sddm/themes/$theme_name" ]; then
  sudo rm -rf "/usr/share/sddm/themes/$theme_name"
  echo -e "\e[1A\e[K${OK} - Removed existing $theme_name directory." 2>&1 | tee -a "$LOG"
fi

# Clone the theme repository
if git clone --depth 1 "$source_theme" "/tmp/$theme_name" 2>&1 | tee -a "$LOG"; then
  sudo cp -r "/tmp/$theme_name" "/usr/share/sddm/themes/" 2>&1 | tee -a "$LOG"
  rm -rf "/tmp/$theme_name"
  echo -e "\e[1A\e[K${OK} - Theme cloned and copied successfully." 2>&1 | tee -a "$LOG"
else
  echo -e "\e[1A\e[K${ERROR} - Failed to clone the theme repository." 2>&1 | tee -a "$LOG"
fi

# Update sddm.conf to use the newly installed theme and configure qtvirtualkeyboard
sddm_conf="/etc/sddm.conf"
if [ -f "$sddm_conf" ]; then
  # Check if [Theme] section exists
  if grep -q '^\[Theme\]' "$sddm_conf"; then
    # Ensure Current= is properly updated
    if grep -q '^Current=' "$sddm_conf"; then
      sudo sed -i "s/^Current=.*/Current=$theme_name/" "$sddm_conf" 2>&1 | tee -a "$LOG"
      echo "Updated Current to $theme_name in $sddm_conf" | tee -a "$LOG"
    else
      sudo sed -i "/^\[Theme\]/a Current=$theme_name" "$sddm_conf" 2>&1 | tee -a "$LOG"
      echo "Added Current=$theme_name under [Theme] in $sddm_conf" | tee -a "$LOG"
    fi
  else
    # Create [Theme] section and add Current
    echo -e "\n[Theme]\nCurrent=$theme_name" | sudo tee -a "$sddm_conf" > /dev/null
    echo "Added [Theme] section with Current=$theme_name in $sddm_conf" | tee -a "$LOG"
  fi

  # Add [General] section with InputMethod=qtvirtualkeyboard if it doesn't exist
  if ! grep -q '^\[General\]' "$sddm_conf"; then
    echo -e "\n[General]\nInputMethod=qtvirtualkeyboard" | sudo tee -a "$sddm_conf" > /dev/null
    echo "Added [General] section with InputMethod=qtvirtualkeyboard in $sddm_conf" | tee -a "$LOG"
  else
    # Update InputMethod line if section exists
    if grep -q '^\s*InputMethod=' "$sddm_conf"; then
      sudo sed -i '/^\[General\]/,/^\[/{s/^\s*InputMethod=.*/InputMethod=qtvirtualkeyboard/}' "$sddm_conf" 2>&1 | tee -a "$LOG"
      echo "Updated InputMethod to qtvirtualkeyboard in $sddm_conf" | tee -a "$LOG"
    else
      sudo sed -i '/^\[General\]/a InputMethod=qtvirtualkeyboard' "$sddm_conf" 2>&1 | tee -a "$LOG"
      echo "Appended InputMethod=qtvirtualkeyboard under [General] in $sddm_conf" | tee -a "$LOG"
    fi
  fi

  # Replace current background from assets
  sudo cp -r assets/sddm.png "/usr/share/sddm/themes/$theme_name/Backgrounds/default" 2>&1 | tee -a "$LOG"
  echo "Replaced theme background with assets/sddm.png" | tee -a "$LOG"
else
  # Create a new sddm.conf if it doesn't exist
  echo -e "[Theme]\nCurrent=$theme_name\n\n[General]\nInputMethod=qtvirtualkeyboard" | sudo tee "$sddm_conf" > /dev/null
  echo "Created $sddm_conf with $theme_name and qtvirtualkeyboard" | tee -a "$LOG"
  sudo cp -r assets/sddm.png "/usr/share/sddm/themes/$theme_name/Backgrounds/default" 2>&1 | tee -a "$LOG"
fi

printf "\n%.0s" {1..2}
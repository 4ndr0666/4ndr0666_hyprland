#!/bin/bash
# === 4ndr0666 === #
# SDDM themes #

set -Eeuo pipefail

source_theme="https://github.com/4ndr0666/simple-sddm-2.git"
theme_name="simple_sddm_2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core/ui.sh"

PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || { echo "${ERROR} Failed to change directory to $PARENT_DIR"; exit 1; }

LOG="Install-Logs/install-$(date +%d-%H%M%S)_sddm_theme.log"

printf "${NOTE} Installing ${SKY_BLUE}Additional SDDM Theme${RESET}\n"

if [ -d "/usr/share/sddm/themes/$theme_name" ]; then
  sudo rm -rf "/usr/share/sddm/themes/$theme_name"
  echo -e "\e[1A\e[K${OK} - Removed existing $theme_name directory." 2>&1 | tee -a "$LOG"
fi

if git clone --depth 1 "$source_theme" "/tmp/$theme_name" 2>&1 | tee -a "$LOG"; then
  sudo cp -r "/tmp/$theme_name" "/usr/share/sddm/themes/" 2>&1 | tee -a "$LOG"
  rm -rf "/tmp/$theme_name"
  echo -e "\e[1A\e[K${OK} - Theme cloned and copied successfully." 2>&1 | tee -a "$LOG"
else
  echo -e "\e[1A\e[K${ERROR} - Failed to clone the theme repository." 2>&1 | tee -a "$LOG"
fi

sddm_conf="/etc/sddm.conf"
if [ -f "$sddm_conf" ]; then
  if grep -q '^\[Theme\]' "$sddm_conf"; then
    if grep -q '^Current=' "$sddm_conf"; then
      sudo sed -i "s/^Current=.*/Current=$theme_name/" "$sddm_conf" 2>&1 | tee -a "$LOG"
      echo "Updated Current to $theme_name in $sddm_conf" | tee -a "$LOG"
    else
      sudo sed -i "/^\[Theme\]/a Current=$theme_name" "$sddm_conf" 2>&1 | tee -a "$LOG"
      echo "Added Current=$theme_name under [Theme] in $sddm_conf" | tee -a "$LOG"
    fi
  else
    echo -e "\n[Theme]\nCurrent=$theme_name" | sudo tee -a "$sddm_conf" > /dev/null
    echo "Added [Theme] section with Current=$theme_name in $sddm_conf" | tee -a "$LOG"
  fi

  if ! grep -q '^\[General\]' "$sddm_conf"; then
    echo -e "\n[General]\nInputMethod=qtvirtualkeyboard" | sudo tee -a "$sddm_conf" > /dev/null
    echo "Added [General] section with InputMethod=qtvirtualkeyboard" | tee -a "$LOG"
  else
    if grep -q '^\s*InputMethod=' "$sddm_conf"; then
      sudo sed -i '/^\[General\]/,/^\[/{s/^\s*InputMethod=.*/InputMethod=qtvirtualkeyboard/}' "$sddm_conf" 2>&1 | tee -a "$LOG"
      echo "Updated InputMethod to qtvirtualkeyboard in $sddm_conf" | tee -a "$LOG"
    else
      sudo sed -i '/^\[General\]/a InputMethod=qtvirtualkeyboard' "$sddm_conf" 2>&1 | tee -a "$LOG"
      echo "Appended InputMethod=qtvirtualkeyboard under [General]" | tee -a "$LOG"
    fi
  fi

  sudo cp -r assets/sddm.png "/usr/share/sddm/themes/$theme_name/Backgrounds/default" 2>&1 | tee -a "$LOG"
  echo "Replaced theme background with assets/sddm.png" | tee -a "$LOG"
else
  echo -e "[Theme]\nCurrent=$theme_name\n\n[General]\nInputMethod=qtvirtualkeyboard" | sudo tee "$sddm_conf" > /dev/null
  echo "Created $sddm_conf with $theme_name and qtvirtualkeyboard" | tee -a "$LOG"
  sudo cp -r assets/sddm.png "/usr/share/sddm/themes/$theme_name/Backgrounds/default" 2>&1 | tee -a "$LOG"
fi

printf "\n%.0s" {1..2}

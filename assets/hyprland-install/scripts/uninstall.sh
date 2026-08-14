#!/bin/bash
# === 4ndr0666 === #

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

printf "\n%.0s" {1..2}
echo -e "\e[35m
# ========================================= #
# ===           4ndr0666                === #
# ===      Arch Linux UNINSTALL         === #
# ========================================= #
\e[0m"

# Ask the user for confirmation
if ! whiptail --title "Confirmation" --yesno "Are you sure you want to remove the selected packages and directories?\n\nWARNING! This action is irreversible." \
10 80; then
    echo "$INFO uninstall process canceled."
    exit 1
fi

printf "\n%.0s" {1..1}
printf "\n%s${SKY_BLUE}Attempting to remove selected packages${RESET}\n" "${NOTE}"
MAX_ATTEMPTS=2
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    # Remove packages
    remove_packages /tmp/selected_packages.txt

    # Check if any packages still need to be removed, retry if needed
    MISSING_PACKAGE_COUNT=0
    while read -r package; do
        if pacman -Qi "$package" &> /dev/null; then
            MISSING_PACKAGE_COUNT=$((MISSING_PACKAGE_COUNT + 1))
        fi
    done < /tmp/selected_packages.txt

    if [ $MISSING_PACKAGE_COUNT -gt 0 ]; then
        ATTEMPT=$((ATTEMPT + 1))
        echo "Attempt #$ATTEMPT failed, retrying..."
    else
        break
    fi
done

printf "\n%.0s" {1..1}
printf "\n%s${SKY_BLUE}Attempting to remove locally installed packages${RESET}\n" "${NOTE}"
for file in ags pokemon-colorscripts; do
    if [ -f "/usr/local/bin/$file" ]; then
        sudo rm "/usr/local/bin/$file"
        echo "$file removed."
    fi
done

printf "\n%.0s" {1..1}
printf "\n%s${SKY_BLUE}Uninstall Process Finished${RESET}\n" "${NOTE}"
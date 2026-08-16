#!/usr/bin/env bash
# === 4ndr0666 === #
# For downloading dots from releases

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

# Check /etc/os-release for Ubuntu or Debian and warn about Hyprland version requirement
if grep -iqE '^(ID_LIKE|ID)=.*(ubuntu|debian)' /etc/os-release >/dev/null 2>&1; then
  printf "\n%.0s" {1..1}
  echo "${WARNING} These Dotfiles are only supported on Hyprland 0.51.1 or greater. Do not install on older revisions.${RESET}"
  while true; do
    echo -n "${CAT} Do you want to continue anyway? (y/N): ${RESET}"
    read _continue
    _continue=$(echo "${_continue}" | tr '[:upper:]' '[:lower:]')
    case "${_continue}" in
      y|yes)
        echo "${NOTE} Proceeding on Ubuntu/Debian by user confirmation." 
        break
        ;;
      n|no|"")
        printf "\n%.0s" {1..1}
        echo "${INFO} Aborting per user choice. No changes made." 
        printf "\n%.0s" {1..1}
        exit 1
        ;;
      *)
        echo "${WARN} Please answer 'y' or 'n'." 
        ;;
    esac
  done
fi


printf "\n%.0s" {1..1}  
echo -e "\e[35m
# ========================================= #
# ===           4ndr0666                === #
# ===       Release Downloader          === #
# ========================================= #
\e[0m"
printf "\n%.0s" {1..1}  

echo "${WARNING}A T T E N T I O N !${RESET}"
echo "${SKY_BLUE}This script is meant to download from the RELEASES on the 4ndr0666_hyprland repository${RESET}"
echo "${YELLOW}Kindly note that the RELEASES is one version older than from main${RESET}"
printf "\n%.0s" {1..1}
echo "${MAGENTA}If you want to get the latest, kindly run the ${SKY_BLUE}copy.sh${RESET} ${MAGENTA}instead${RESET}"
printf "\n%.0s" {1..1}
read -p "${CAT} - Would you like to proceed and install from releases? (y/n): ${RESET}" proceed

if [ "$proceed" != "y" ]; then
    printf "\n%.0s" {1..1}
    echo "${INFO} Installation aborted. ${SKY_BLUE}No changes in your system.${RESET} ${YELLOW}Goodbye!${RESET}"
    printf "\n%.0s" {1..1}
    exit 1
fi

printf "${NOTE} Downloading / Checking for existing 4ndr0666_hyprland.tar.gz...\n"

# Check if 4ndr0666_hyprland.tar.gz exists
if [ -f 4ndr0666_hyprland.tar.gz ]; then
  printf "${NOTE} 4ndr0666_hyprland.tar.gz found.\n"

  # Get the version from the existing tarball filename
  existing_version=$(echo 4ndr0666_hyprland.tar.gz | grep -oP 'v\d+\.\d+\.\d+' | sed 's/v//')

  # Fetch the tag_name for the latest release using the GitHub API
  latest_version=$(curl -s https://api.github.com/repos/4ndr0666/4ndr0666_hyprland/releases/latest | grep "tag_name" | cut -d '"' -f 4 | sed 's/v//')

  # Check if versions match
  if [ "$existing_version" = "$latest_version" ]; then
    echo -e "${OK} 4ndr0666_hyprland.tar.gz is up-to-date with the latest release ($latest_version)."
    
    # Sleep for 10 seconds before exiting
    printf "${NOTE} No update found. Sleeping for 10 seconds...\n"
    sleep 10
    exit 0
  else
    echo -e "${WARN} 4ndr0666_hyprland.tar.gz is outdated (Existing version: $existing_version, Latest version: $latest_version)."
    read -p "Do you want to upgrade to the latest version? (y/n): " upgrade_choice
    if [ "$upgrade_choice" = "y" ]; then
		echo -e "${NOTE} Proceeding to download the latest release."
		
		# Delete existing directories starting with 4ndr0666_hyprland
      find . -type d -name '4ndr0666_hyprland*' -exec rm -rf {} +
      rm -f 4ndr0666_hyprland.tar.gz
      printf "${WARN} Removed existing 4ndr0666_hyprland.tar.gz.\n"
    else
      echo -e "${NOTE} User chose not to upgrade. Exiting..."
      exit 0
    fi
  fi
fi

printf "${NOTE} Downloading the latest source code release...\n"

# Fetch the tag name for the latest release using the GitHub API
latest_tag=$(curl -s https://api.github.com/repos/4ndr0666/4ndr0666_hyprland/releases/latest | grep "tag_name" | cut -d '"' -f 4)

# Check if the tag is obtained successfully
if [ -z "$latest_tag" ]; then
  echo -e "${ERROR} Unable to fetch the latest tag information."
  exit 1
fi

# Fetch the tarball URL for the latest release using the GitHub API
latest_tarball_url=$(curl -s https://api.github.com/repos/4ndr0666/4ndr0666_hyprland/releases/latest | grep "tarball_url" | cut -d '"' -f 4)

# Check if the URL is obtained successfully
if [ -z "$latest_tarball_url" ]; then
  echo -e "${ERROR} Unable to fetch the tarball URL for the latest release."
  exit 1
fi

# Get the filename from the URL and include the tag name in the file name
file_name="4ndr0666_hyprland-${latest_tag}.tar.gz"

# Download the latest release source code tarball to the current directory
if curl -L "$latest_tarball_url" -o "$file_name"; then
  # Extract the contents of the tarball
  tar -xzf "$file_name" || exit 1

  # delete existing extracted targets
  rm -rf 4ndr0666_hyprland-extracted

  # Identify the extracted directory
  extracted_directory=$(tar -tf "$file_name" | grep -o '^[^/]\+' | uniq)

  # Rename the extracted directory to 4ndr0666_hyprland-extracted
  mv "$extracted_directory" 4ndr0666_hyprland-extracted || exit 1

  cd "4ndr0666_hyprland-extracted" || exit 1

  # Set execute permission for copy.sh and execute it
  chmod +x copy.sh
  ./copy.sh 2>&1 | tee -a "../install-$(date +'%d-%H%M%S')_dots.log"

  echo -e "${OK} Latest source code release downloaded, extracted, and processed successfully."
else
  echo -e "${ERROR} Failed to download the latest source code release."
  exit 1
fi
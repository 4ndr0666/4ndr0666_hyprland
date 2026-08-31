#!/bin/bash
# https://github.com/4ndr0666

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

Distro="Arch-Hyprland"
Github_URL="https://github.com/4ndr0666/$Distro.git"
Distro_DIR="$HOME/$Distro"
RELEASE_REF="f1468f500a14ef6ff25ff03ddee8a64044c96849"

if ! command -v git >/dev/null 2>&1; then
    printf '%s\n' '[INFO] Git not found; installing it from the Arch repositories.'
    sudo pacman -S --noconfirm git
fi

if [[ -e "$Distro_DIR" && ! -d "$Distro_DIR/.git" ]]; then
    printf 'Refusing to overwrite non-repository path: %s\n' "$Distro_DIR" >&2
    exit 1
fi

if [[ ! -d "$Distro_DIR/.git" ]]; then
    echo "${YELLOW}$Distro_DIR exists. Updating the repository... ${RESET}"
    git clone "$Github_URL" "$Distro_DIR"
fi

cd "$Distro_DIR"
git fetch --no-tags origin "$RELEASE_REF"
git checkout --detach "$RELEASE_REF"
[[ "$(git rev-parse HEAD)" == "$RELEASE_REF" ]] || {
    printf '%s\n' 'Installer revision verification failed.' >&2
    exit 1
}

exec ./install.sh

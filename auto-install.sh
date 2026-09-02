#!/usr/bin/env bash
# === 4ndr0666 === #
# Immutable bootstrap for this repository at a pinned release revision.

set -Eeuo pipefail

REPOSITORY_URL="https://github.com/4ndr0666/Arch-Hyprland.git"
Distro_DIR="$HOME/Arch-Hyprland"
RELEASE_REF="f1468f500a14ef6ff25ff03ddee8a64044c96849"

if ! command -v git >/dev/null 2>&1; then
    printf '%s\n' '[INFO] Git not found; installing it from the Arch repositories.'
    sudo pacman -S --noconfirm git
fi

if [[ -e "$Distro_DIR" ]]; then
    printf '%s\n' "[ERROR] Refusing to mutate existing installation path: $Distro_DIR" >&2
    exit 1
fi

printf '%s\n' "[INFO] Cloning repository at immutable revision $RELEASE_REF."
git clone --no-checkout "$REPOSITORY_URL" "$Distro_DIR"
cd "$Distro_DIR"
git fetch --depth=1 --no-tags origin "$RELEASE_REF"
git checkout --detach --force "$RELEASE_REF"

[[ "$(git rev-parse HEAD)" == "$RELEASE_REF" ]] || {
    printf '%s\n' '[ERROR] Installer revision verification failed.' >&2
    exit 1
}

exec ./install.sh

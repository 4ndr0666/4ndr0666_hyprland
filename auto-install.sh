#!/usr/bin/env bash
# === 4ndr0666 === #
# Bootstrap the reviewed installer revision without executing mutable HEAD.

set -Eeuo pipefail

Distro="4ndr0666_hyprland"
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

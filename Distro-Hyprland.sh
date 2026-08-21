#!/usr/bin/env bash
# === 4ndr0666 === #
# Bootstrap a distro-specific Hyprland installer at an immutable revision.

set -Eeuo pipefail

OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
YELLOW="$(tput setaf 3)"
RESET="$(tput sgr0)"

# A mutable branch/tag is not an acceptable execution target for a bootstrapper.
# Supply the exact 40-character commit selected by the release maintainer.
INSTALL_REF="${HYPRLAND_INSTALL_REF:-}"
if [[ ! "$INSTALL_REF" =~ ^[0-9a-fA-F]{40}$ ]]; then
    printf '%s\n' "${ERROR} HYPRLAND_INSTALL_REF must be a full 40-character commit ID." >&2
    printf '%s\n' "${INFO} Refusing to execute mutable branch/tag content." >&2
    exit 2
fi

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
else
    printf '%s\n' "${ERROR} Unable to detect the distribution." >&2
    exit 1
fi

distro_name="${NAME:-}"
distro_version="${VERSION_ID:-}"
PACKAGE_MANAGER=""
Distro=""
Github_URL=""
Distro_DIR=""

case "$distro_name" in
    "Debian GNU/Linux")
        PACKAGE_MANAGER="apt"
        Distro="Debian-Hyprland"
        ;;
    "Ubuntu")
        PACKAGE_MANAGER="apt"
        Distro="Ubuntu-Hyprland"
        ;;
    "NixOS")
        PACKAGE_MANAGER="nix"
        Distro="NixOS-Hyprland"
        ;;
    *)
        if command -v pacman >/dev/null 2>&1; then
            PACKAGE_MANAGER="pacman"
            Distro="Arch-Hyprland"
        elif command -v dnf >/dev/null 2>&1; then
            PACKAGE_MANAGER="dnf"
            Distro="Fedora-Hyprland"
        elif command -v zypper >/dev/null 2>&1; then
            PACKAGE_MANAGER="zypper"
            Distro="OpenSUSE-Hyprland"
        else
            printf '%s\n' "${ERROR} Unsupported distribution: $distro_name." >&2
            exit 1
        fi
        ;;
esac

case "$distro_name:$distro_version" in
    "Ubuntu:24.04") Github_URL_BRANCH="24.04" ;;
    "Ubuntu:24.10") Github_URL_BRANCH="24.10" ;;
    "Ubuntu:25.04") Github_URL_BRANCH="25.04" ;;
    "Ubuntu:25.10") Github_URL_BRANCH="25.10" ;;
    "Ubuntu:26.04-development") Github_URL_BRANCH="26.04-development" ;;
    "Ubuntu:"*)
        printf '%s\n' "${ERROR} Unsupported Ubuntu release: $distro_version." >&2
        exit 1
        ;;
    *)
        Github_URL_BRANCH=""
        ;;
esac

Github_URL="https://github.com/4ndr0666/${Distro}.git"
Distro_DIR="$HOME/$Distro"
[[ -n "${Github_URL_BRANCH}" ]] && Distro_DIR="$HOME/${Distro}-${Github_URL_BRANCH}"

if ! command -v git >/dev/null 2>&1; then
    printf '%s\n' "${ERROR} Git is required before bootstrap can continue." >&2
    printf '%s\n' "${INFO} Install git with the distribution package manager, then rerun." >&2
    exit 1
fi

if [[ -d "$Distro_DIR" ]]; then
    printf '%s\n' "${YELLOW}$Distro_DIR already exists. Automatic update is disabled.${RESET}"
    printf '%s\n' "${INFO} The existing checkout will not be mutated by this bootstrapper."
    exit 1
fi

printf '%s\n' "${INFO} Cloning $Distro at immutable revision $INSTALL_REF."
git clone --no-checkout "$Github_URL" "$Distro_DIR"
cd "$Distro_DIR"
git fetch --depth=1 origin "$INSTALL_REF"
git checkout --detach --force "$INSTALL_REF"

actual_ref="$(git rev-parse HEAD)"
if [[ "$actual_ref" != "$INSTALL_REF" ]]; then
    printf '%s\n' "${ERROR} Checked-out revision does not match requested revision." >&2
    exit 1
fi

chmod +x -- install.sh
exec ./install.sh

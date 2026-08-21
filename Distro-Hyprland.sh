#!/usr/bin/env bash
# === 4ndr0666 === #
# Arch Linux bootstrap for this repository at an immutable revision.

set -Eeuo pipefail

ERROR='[ERROR]'
INFO='[INFO]'

INSTALL_REF="${HYPRLAND_INSTALL_REF:-}"
if [[ ! "$INSTALL_REF" =~ ^[0-9a-fA-F]{40}$ ]]; then
    printf '%s HYPRLAND_INSTALL_REF must be a full 40-character commit ID.\n' "$ERROR" >&2
    printf '%s Mutable branches and tags are not accepted by the bootstrapper.\n' "$INFO" >&2
    exit 2
fi

if [[ ! -r /etc/os-release ]]; then
    printf '%s Unable to detect the operating system.\n' "$ERROR" >&2
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
if [[ "${ID:-}" != "arch" ]]; then
    printf '%s This repository currently supports Arch Linux only (detected: %s).\n' "$ERROR" "${PRETTY_NAME:-${ID:-unknown}}" >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    printf '%s Git is required before bootstrap can continue.\n' "$ERROR" >&2
    exit 1
fi

REPOSITORY_URL="https://github.com/4ndr0666/4ndr0666_hyprland.git"
INSTALL_DIR="${HYPRLAND_INSTALL_DIR:-$HOME/4ndr0666_hyprland}"

if [[ -e "$INSTALL_DIR" ]]; then
    printf '%s Refusing to mutate existing checkout: %s\n' "$ERROR" "$INSTALL_DIR" >&2
    exit 1
fi

printf '%s Cloning repository at immutable revision %s.\n' "$INFO" "$INSTALL_REF"
git clone --no-checkout "$REPOSITORY_URL" "$INSTALL_DIR"
cd "$INSTALL_DIR"
git fetch --depth=1 origin "$INSTALL_REF"
git checkout --detach --force "$INSTALL_REF"

actual_ref="$(git rev-parse HEAD)"
if [[ "$actual_ref" != "$INSTALL_REF" ]]; then
    printf '%s Checked-out revision does not match requested revision.\n' "$ERROR" >&2
    exit 1
fi

chmod +x -- install.sh
exec ./install.sh

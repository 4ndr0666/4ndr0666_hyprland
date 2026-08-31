#!/bin/bash
# Bootstrap exactly one supported AUR helper: yay.
# This is the only bootstrap exception to the normal package transaction path.
# AUR repository refs are deliberately mandatory: mutable AUR HEAD is not an
# acceptable supply-chain input for an unattended installer.

set -Eeuo pipefail

AUR_BOOTSTRAP_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0666-hyprland/aur-bootstrap"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVENANCE_FILE="$SCRIPT_DIR/aur-provenance.conf"

package_bootstrap_aur_helper() {
  local package="$1"
  local build_dir="$AUR_BOOTSTRAP_ROOT/$package"
  local ref=""

  command -v yay >/dev/null 2>&1 && return 0

  [[ "$package" == "yay-bin" ]] || {
    printf '[ERROR] Unsupported AUR helper bootstrap target: %s. Only yay-bin is supported.\n' "$package" >&2
    return 1
  }

  # Load repository-owned provenance; do not permit an ambient environment
  # value to override the reviewed pin.
  source "$PROVENANCE_FILE"
  ref="${AUR_YAY_BIN_REF:-}"

  [[ "$ref" =~ ^[0-9a-fA-F]{40}$ ]] || {
    printf '[ERROR] Invalid immutable AUR revision configured for yay-bin.\n' >&2
    return 1
  }

  command -v git >/dev/null 2>&1 || { printf '[ERROR] git is required to bootstrap yay.\n' >&2; return 1; }
  command -v makepkg >/dev/null 2>&1 || { printf '[ERROR] makepkg is required to bootstrap yay.\n' >&2; return 1; }

  rm -rf -- "$build_dir"
  mkdir -p -- "$AUR_BOOTSTRAP_ROOT"
  git init --quiet -- "$build_dir"
  git -C "$build_dir" remote add origin "https://aur.archlinux.org/yay-bin.git"
  git -C "$build_dir" fetch --quiet --depth=1 origin "$ref"
  git -C "$build_dir" checkout --quiet --detach "$ref"

  [[ "$(git -C "$build_dir" rev-parse HEAD)" == "$ref" ]] || {
    printf '[ERROR] AUR revision verification failed for yay-bin.\n' >&2
    return 1
  }

  makepkg -Ccfsi --noconfirm --needed --directory "$build_dir"

  command -v yay >/dev/null 2>&1 || {
    printf '[ERROR] yay bootstrap completed without installing yay.\n' >&2
    return 1
  }
}

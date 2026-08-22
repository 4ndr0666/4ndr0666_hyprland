#!/bin/bash
# Bootstrap exactly one AUR helper when no helper is installed yet.
# This is the only bootstrap exception to the normal package transaction path.
# AUR repository refs are deliberately mandatory: mutable AUR HEAD is not an
# acceptable supply-chain input for an unattended installer.

set -Eeuo pipefail

AUR_BOOTSTRAP_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0666-hyprland/aur-bootstrap"

package_bootstrap_aur_helper() {
  local package="$1"
  local build_dir="$AUR_BOOTSTRAP_ROOT/$package"
  local ref=""

  command -v yay >/dev/null 2>&1 && return 0
  command -v paru >/dev/null 2>&1 && return 0

  case "$package" in
    yay-bin) ref="${AUR_YAY_BIN_REF:-}" ;;
    paru-bin) ref="${AUR_PARU_BIN_REF:-}" ;;
    *) printf '[ERROR] Unsupported AUR helper bootstrap target: %s\n' "$package" >&2; return 1 ;;
  esac

  [[ "$ref" =~ ^[0-9a-fA-F]{40}$ ]] || {
    printf '[ERROR] No immutable AUR revision configured for %s. Set the corresponding AUR_*_REF to a 40-character commit SHA.\n' "$package" >&2
    return 1
  }

  command -v git >/dev/null 2>&1 || { printf '[ERROR] git is required to bootstrap an AUR helper.\n' >&2; return 1; }
  command -v makepkg >/dev/null 2>&1 || { printf '[ERROR] makepkg is required to bootstrap an AUR helper.\n' >&2; return 1; }

  rm -rf -- "$build_dir"
  mkdir -p -- "$AUR_BOOTSTRAP_ROOT"
  git init --quiet -- "$build_dir"
  git -C "$build_dir" remote add origin "https://aur.archlinux.org/${package}.git"
  git -C "$build_dir" fetch --quiet --depth=1 origin "$ref"
  git -C "$build_dir" checkout --quiet --detach "$ref"

  [[ "$(git -C "$build_dir" rev-parse HEAD)" == "$ref" ]] || {
    printf '[ERROR] AUR revision verification failed for %s.\n' "$package" >&2
    return 1
  }

  makepkg -Ccfsi --noconfirm --needed --directory "$build_dir"

  command -v yay >/dev/null 2>&1 || command -v paru >/dev/null 2>&1 || {
    printf '[ERROR] AUR helper bootstrap completed without installing an AUR helper.\n' >&2
    return 1
  }
}

#!/bin/bash
# Bootstrap exactly one AUR helper when no helper is installed yet.
# This is the only bootstrap exception to the normal package transaction path.

set -Eeuo pipefail

AUR_BOOTSTRAP_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0666-hyprland/aur-bootstrap"

package_bootstrap_aur_helper() {
  local package="$1"
  local build_dir="$AUR_BOOTSTRAP_ROOT/$package"

  command -v yay >/dev/null 2>&1 && return 0
  command -v paru >/dev/null 2>&1 && return 0

  case "$package" in
    yay-bin|paru-bin) ;;
    *) printf '[ERROR] Unsupported AUR helper bootstrap target: %s\n' "$package" >&2; return 1 ;;
  esac

  command -v git >/dev/null 2>&1 || { printf '[ERROR] git is required to bootstrap an AUR helper.\n' >&2; return 1; }
  command -v makepkg >/dev/null 2>&1 || { printf '[ERROR] makepkg is required to bootstrap an AUR helper.\n' >&2; return 1; }

  rm -rf -- "$build_dir"
  mkdir -p -- "$AUR_BOOTSTRAP_ROOT"
  git clone --depth=1 -- "https://aur.archlinux.org/${package}.git" "$build_dir"
  makepkg -Ccfsi --noconfirm --needed --directory "$build_dir"

  command -v yay >/dev/null 2>&1 || command -v paru >/dev/null 2>&1 || {
    printf '[ERROR] AUR helper bootstrap completed without installing an AUR helper.\n' >&2
    return 1
  }
}

#!/bin/bash
# === 4ndr0666 === #
# Package transaction primitives.
#
# The package manager's foreground exit status is authoritative. This file
# deliberately does not poll child processes or infer transaction success from
# package presence after the fact.

PACKAGE_MANIFEST_DEFAULT="${XDG_STATE_HOME:-$HOME/.local/state}/4ndr0666-hyprland/packages.manifest"

package_core_init() {
  : "${PACKAGE_MANIFEST:=$PACKAGE_MANIFEST_DEFAULT}"
  : "${LOG:=/dev/stderr}"
  mkdir -p "$(dirname "$PACKAGE_MANIFEST")"
  touch "$PACKAGE_MANIFEST"
}

package_core_log() {
  printf '%s\n' "$*" | tee -a "$LOG"
}

package_aur_helper() {
  if command -v yay >/dev/null 2>&1; then
    printf '%s\n' yay
    return 0
  fi
  if command -v paru >/dev/null 2>&1; then
    printf '%s\n' paru
    return 0
  fi
  return 1
}

package_is_installed() {
  pacman -Q -- "$1" >/dev/null 2>&1
}

package_manifest_contains() {
  grep -Fqx -- "$1" "$PACKAGE_MANIFEST"
}

package_manifest_record() {
  local package="$1"
  if ! package_manifest_contains "$package"; then
    printf '%s\n' "$package" >> "$PACKAGE_MANIFEST"
  fi
}

package_normalize() {
  local package
  for package in "$@"; do
    [[ -n "$package" ]] || continue
    printf '%s\n' "$package"
  done | awk '!seen[$0]++'
}

package_run_with_log() {
  local rc
  local had_errexit=0

  case $- in
    *e*) had_errexit=1; set +e ;;
  esac

  "$@" 2>&1 | tee -a "$LOG"
  rc=${PIPESTATUS[0]}

  if ((had_errexit)); then
    set -e
  fi

  return "$rc"
}

package_install_official() {
  local -a packages=("$@")
  ((${#packages[@]})) || return 0
  package_core_log "[INFO] Installing official packages: ${packages[*]}"
  package_run_with_log sudo pacman -S --needed --noconfirm -- "${packages[@]}"
}

package_install_aur() {
  local -a packages=("$@")
  local helper
  ((${#packages[@]})) || return 0

  helper="$(package_aur_helper)" || {
    package_core_log "[ERROR] AUR packages requested but neither yay nor paru is installed."
    return 1
  }

  package_core_log "[INFO] Installing AUR packages with ${helper}: ${packages[*]}"
  package_run_with_log "$helper" -S --needed --noconfirm -- "${packages[@]}"
}

package_install() {
  local package
  local -a requested=()
  local -a official=()
  local -a aur=()
  local -a newly_owned=()

  package_core_init
  mapfile -t requested < <(package_normalize "$@")
  ((${#requested[@]})) || return 0

  for package in "${requested[@]}"; do
    if package_is_installed "$package"; then
      package_core_log "[INFO] ${package} is already installed; ownership unchanged."
    else
      newly_owned+=("$package")
    fi
  done

  if ((${#newly_owned[@]})) && ! command -v pacman >/dev/null 2>&1; then
    package_core_log "[ERROR] pacman is required on Arch Linux."
    return 1
  fi

  # pacman -Si identifies packages available from configured repositories.
  # Names unavailable there are handed to the AUR helper.
  for package in "${newly_owned[@]}"; do
    if pacman -Si -- "$package" >/dev/null 2>&1; then
      official+=("$package")
    else
      aur+=("$package")
    fi
  done

  if ((${#official[@]})); then
    package_install_official "${official[@]}" || return $?
  fi

  if ((${#aur[@]})); then
    package_install_aur "${aur[@]}" || return $?
  fi

  # Record only explicitly requested packages that are now present. Dependencies
  # pulled in by the transaction are deliberately not installer-owned.
  for package in "${newly_owned[@]}"; do
    if package_is_installed "$package"; then
      package_manifest_record "$package"
    else
      package_core_log "[ERROR] Package transaction completed without ${package} being installed."
      return 1
    fi
  done
}

package_remove_owned() {
  local package
  local -a owned=()

  package_core_init
  mapfile -t owned < "$PACKAGE_MANIFEST"
  ((${#owned[@]})) || return 0

  for package in "${owned[@]}"; do
    [[ -n "$package" ]] || continue
    if package_is_installed "$package"; then
      package_core_log "[INFO] Removing installer-owned package: ${package}"
      package_run_with_log sudo pacman -R --noconfirm -- "$package" || return $?
    else
      package_core_log "[INFO] Installer-owned package already absent: ${package}"
    fi
  done
}

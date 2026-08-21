#!/bin/bash
# === 4ndr0666 === #
# Package transaction primitives.

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
  if command -v yay >/dev/null 2>&1; then printf '%s\n' yay; return 0; fi
  if command -v paru >/dev/null 2>&1; then printf '%s\n' paru; return 0; fi
  return 1
}

package_is_installed() { pacman -Q -- "$1" >/dev/null 2>&1; }
package_manifest_contains() { grep -Fqx -- "$1" "$PACKAGE_MANIFEST"; }

package_manifest_record() {
  local package="$1"
  package_manifest_contains "$package" || printf '%s\n' "$package" >> "$PACKAGE_MANIFEST"
}

package_normalize() {
  local package
  for package in "$@"; do [[ -n "$package" ]] && printf '%s\n' "$package"; done | awk '!seen[$0]++'
}

package_run_with_log() {
  local rc had_errexit=0
  case $- in *e*) had_errexit=1; set +e ;; esac
  "$@" 2>&1 | tee -a "$LOG"
  rc=${PIPESTATUS[0]}
  ((had_errexit)) && set -e
  return "$rc"
}

package_sync() {
  package_core_init
  package_core_log '[INFO] Synchronizing Arch package databases.'
  package_run_with_log sudo pacman -Sy
}

package_record_newly_owned() {
  local package
  for package in "$@"; do
    if package_is_installed "$package"; then
      package_manifest_record "$package"
    else
      package_core_log "[ERROR] Package transaction completed without ${package} being installed."
      return 1
    fi
  done
}

package_install() {
  local package
  local -a requested=() newly_owned=()
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
  ((${#newly_owned[@]})) || return 0
  package_core_log "[INFO] Installing official packages: ${newly_owned[*]}"
  package_run_with_log sudo pacman -S --needed --noconfirm -- "${newly_owned[@]}" || return $?
  package_record_newly_owned "${newly_owned[@]}"
}

package_install_aur() {
  local package helper
  local -a requested=() newly_owned=()
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
  ((${#newly_owned[@]})) || return 0
  helper="$(package_aur_helper)" || { package_core_log '[ERROR] AUR packages requested but neither yay nor paru is installed.'; return 1; }
  package_core_log "[INFO] Installing AUR packages with ${helper}: ${newly_owned[*]}"
  package_run_with_log "$helper" -S --needed --noconfirm -- "${newly_owned[@]}" || return $?
  package_record_newly_owned "${newly_owned[@]}"
}

package_remove_owned() {
  local package
  local -a owned=() installed=()
  package_core_init
  mapfile -t owned < "$PACKAGE_MANIFEST"
  ((${#owned[@]})) || return 0
  for package in "${owned[@]}"; do
    [[ -n "$package" ]] || continue
    if package_is_installed "$package"; then installed+=("$package"); else package_core_log "[INFO] Installer-owned package already absent: ${package}"; fi
  done
  ((${#installed[@]})) || return 0
  package_core_log "[INFO] Removing installer-owned packages: ${installed[*]}"
  package_run_with_log sudo pacman -R --noconfirm -- "${installed[@]}" || return $?
  for package in "${installed[@]}"; do
    if package_is_installed "$package"; then
      package_core_log "[ERROR] Package remains installed after removal transaction: ${package}"
      return 1
    fi
  done
  : > "$PACKAGE_MANIFEST"
}

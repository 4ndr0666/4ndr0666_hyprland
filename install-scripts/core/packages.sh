#!/usr/bin/env bash
# Package transaction primitives. Package provenance is explicit at call sites.

PACKAGE_MANIFEST_DEFAULT="${XDG_STATE_HOME:-$HOME/.local/state}/4ndr0666-hyprland/packages.manifest"

package_core_init() {
  : "${PACKAGE_MANIFEST:=$PACKAGE_MANIFEST_DEFAULT}"
  : "${LOG:=/dev/stderr}"
  mkdir -p "$(dirname "$PACKAGE_MANIFEST")"
  touch "$PACKAGE_MANIFEST"
}

package_core_log() { printf '%s\n' "$*" | tee -a "$LOG"; }
package_aur_helper() { command -v yay >/dev/null 2>&1 && { printf '%s\n' yay; return; }; command -v paru >/dev/null 2>&1 && { printf '%s\n' paru; return; }; return 1; }
package_is_installed() { pacman -Q -- "$1" >/dev/null 2>&1; }
package_manifest_contains() { grep -Fqx -- "$1" "$PACKAGE_MANIFEST"; }
package_manifest_record() { package_manifest_contains "$1" || printf '%s\n' "$1" >> "$PACKAGE_MANIFEST"; }

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

package_sync() { package_core_init; package_core_log '[INFO] Synchronizing Arch package databases.'; package_run_with_log sudo pacman -Sy; }

package_record_newly_owned() {
  local package
  for package in "$@"; do
    package_is_installed "$package" && package_manifest_record "$package" || { package_core_log "[ERROR] Package transaction did not install $package."; return 1; }
  done
}

package_install() {
  local package
  local -a requested=() newly_owned=()
  package_core_init
  mapfile -t requested < <(package_normalize "$@")
  for package in "${requested[@]}"; do package_is_installed "$package" || newly_owned+=("$package"); done
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
  for package in "${requested[@]}"; do package_is_installed "$package" || newly_owned+=("$package"); done
  ((${#newly_owned[@]})) || return 0
  helper="$(package_aur_helper)" || { package_core_log '[ERROR] No AUR helper installed.'; return 1; }
  package_core_log "[INFO] Installing AUR packages with ${helper}: ${newly_owned[*]}"
  package_run_with_log "$helper" -S --needed --noconfirm -- "${newly_owned[@]}" || return $?
  package_record_newly_owned "${newly_owned[@]}"
}

package_remove_owned() {
  local package
  local -a owned=() installed=()
  package_core_init
  mapfile -t owned < "$PACKAGE_MANIFEST"
  for package in "${owned[@]}"; do [[ -n "$package" && package_is_installed "$package" ]] && installed+=("$package"); done
  ((${#installed[@]})) || return 0
  package_run_with_log sudo pacman -R --noconfirm -- "${installed[@]}" || return $?
  for package in "${installed[@]}"; do package_is_installed "$package" && { package_core_log "[ERROR] Package remains installed: $package"; return 1; }; done
  : > "$PACKAGE_MANIFEST"
}

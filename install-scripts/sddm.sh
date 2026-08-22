#!/bin/bash
# === 4ndr0666 === #
# SDDM Login Manager

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
LOG="$ROOT_DIR/Install-Logs/install-$(date +%d-%H%M%S)_sddm.log"
mkdir -p "$(dirname "$LOG")"

source "$SCRIPT_DIR/core/packages.sh"
source "$SCRIPT_DIR/core/systemd.sh"

SDDM_STATE_MANIFEST="${XDG_STATE_HOME:-$HOME/.local/state}/4ndr0666-hyprland/sddm.manifest"
mkdir -p "$(dirname "$SDDM_STATE_MANIFEST")"

SDDM_PACKAGES=(
  qt6-declarative
  qt6-svg
  qt6-virtualkeyboard
  qt6-multimedia-ffmpeg
  qt5-quickcontrols2
  sddm
)

LOGIN_MANAGER_UNITS=(
  lightdm.service
  gdm3.service
  gdm.service
  lxdm.service
  lxdm-gtk3.service
  sddm.service
)

wayland_sessions_dir=/usr/share/wayland-sessions

systemd_capture_units "${LOGIN_MANAGER_UNITS[@]}"

restore_on_failure() {
  local rc=$?
  printf '%s\n' '[ERROR] SDDM transition failed; restoring captured service state.' | tee -a "$LOG" >&2
  if ! systemd_restore_units >>"$LOG" 2>&1; then
    printf '%s\n' '[ERROR] Service-state restoration also failed; inspect the SDDM log immediately.' | tee -a "$LOG" >&2
  fi
  if [[ -s "$SDDM_STATE_MANIFEST" ]] && grep -Fqx 'wayland_sessions_dir|created' "$SDDM_STATE_MANIFEST"; then
    if [[ -d "$wayland_sessions_dir" ]] && [[ -z "$(find "$wayland_sessions_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      sudo rmdir -- "$wayland_sessions_dir" >>"$LOG" 2>&1 || true
    fi
  fi
  return "$rc"
}

printf '%s\n' '[ACTION] Installing SDDM and dependencies.' | tee -a "$LOG"
if ! package_install "${SDDM_PACKAGES[@]}"; then
  restore_on_failure
  exit 1
fi

trap restore_on_failure ERR

for unit in "${LOGIN_MANAGER_UNITS[@]}"; do
  [[ "$unit" == sddm.service ]] && continue
  systemd_unit_exists "$unit" || continue

  enabled="$(systemd_unit_enabled_state "$unit")"
  active="$(systemd_unit_active_state "$unit")"

  case "$enabled" in
    masked|disabled|absent)
      ;;
    *)
      printf '[INFO] Disabling %s.\n' "$unit" | tee -a "$LOG"
      sudo systemctl disable -- "$unit" >>"$LOG" 2>&1
      ;;
  esac

  if [[ "$active" == active ]]; then
    printf '[INFO] Stopping active %s.\n' "$unit" | tee -a "$LOG"
    sudo systemctl stop -- "$unit" >>"$LOG" 2>&1
  fi
done

printf '%s\n' '[ACTION] Enabling sddm.service.' | tee -a "$LOG"
sudo systemctl enable -- sddm.service >>"$LOG" 2>&1

[[ "$(systemd_unit_enabled_state sddm.service)" == enabled ]] || {
  printf '%s\n' '[ERROR] sddm.service is not enabled after the transaction.' >&2
  exit 1
}

: > "$SDDM_STATE_MANIFEST"
if [[ ! -d "$wayland_sessions_dir" ]]; then
  printf '[ACTION] Creating %s.\n' "$wayland_sessions_dir" | tee -a "$LOG"
  sudo mkdir -- "$wayland_sessions_dir" >>"$LOG" 2>&1
  printf '%s\n' 'wayland_sessions_dir|created' > "$SDDM_STATE_MANIFEST"
else
  printf '%s\n' 'wayland_sessions_dir|preexisting' > "$SDDM_STATE_MANIFEST"
fi

trap - ERR
printf '%s\n' '[OK] SDDM service transition completed.' | tee -a "$LOG"

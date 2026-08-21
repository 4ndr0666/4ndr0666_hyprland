#!/bin/bash
# NVIDIA system integration.
# Boot configuration is treated as a stateful operation: capture first,
# prepare replacements, then regenerate the derived boot artifacts.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
LOG="$ROOT_DIR/Install-Logs/install-$(date +%d-%H%M%S)_nvidia.log"
mkdir -p -- "$(dirname "$LOG")"

source "$SCRIPT_DIR/core/packages.sh"

log() {
  printf '%s\n' "$*" | tee -a "$LOG"
}

NVIDIA_PACKAGES=(
  nvidia-dkms
  nvidia-settings
  nvidia-utils
  libva
  libva-nvidia-driver
)

mapfile -t KERNELS < <(pacman -Qq | grep -E '^(linux|linux-lts|linux-zen|linux-hardened)$' || true)
if ((${#KERNELS[@]} == 0)); then
  log '[ERROR] No supported installed Arch kernel package was found.'
  exit 1
fi

for kernel in "${KERNELS[@]}"; do
  NVIDIA_PACKAGES+=("${kernel}-headers")
done

log '[ACTION] Installing NVIDIA packages and headers.'
package_install "${NVIDIA_PACKAGES[@]}"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/4ndr0666-hyprland/nvidia"
BACKUP_DIR="$STATE_DIR/backups"
STATE_FILE="$STATE_DIR/state.manifest"
mkdir -p -- "$BACKUP_DIR"
: > "$STATE_FILE"

BACKUPS=()
record_backup() {
  local target="$1" backup="$2" existed="$3"
  printf '%s\t%s\t%s\n' "$target" "$backup" "$existed" >> "$STATE_FILE"
  BACKUPS+=("$target::$backup::$existed")
}

capture_file() {
  local target="$1" name backup
  name="$(printf '%s' "$target" | sed 's#^/##; s#[/]#_#g')"
  backup="$BACKUP_DIR/${name}.bak"
  if sudo test -e "$target" || sudo test -L "$target"; then
    sudo cp -a -- "$target" "$backup"
    record_backup "$target" "$backup" present
  else
    record_backup "$target" "$backup" absent
  fi
}

restore_file() {
  local target="$1" backup="$2" existed="$3"
  if [[ "$existed" == present ]]; then
    sudo cp -a -- "$backup" "$target"
  elif sudo test -e "$target" || sudo test -L "$target"; then
    sudo rm -rf -- "$target"
  fi
}

rollback() {
  local rc=$?
  local pair target backup existed
  log '[ERROR] NVIDIA configuration failed; restoring captured configuration.'
  for pair in "${BACKUPS[@]}"; do
    target="${pair%%::*}"
    pair="${pair#*::}"
    backup="${pair%%::*}"
    existed="${pair#*::}"
    restore_file "$target" "$backup" "$existed" || log "[ERROR] Failed to restore $target"
  done
  return "$rc"
}
trap rollback ERR

# Capture every mutable configuration file before touching it.
capture_file /etc/mkinitcpio.conf
capture_file /etc/modprobe.d/nvidia.conf
capture_file /etc/default/grub

MKINITCPIO_TMP="$(mktemp)"
GRUB_TMP=""
trap 'rm -f -- "$MKINITCPIO_TMP" ${GRUB_TMP:+"$GRUB_TMP"}' EXIT
sudo cp -- /etc/mkinitcpio.conf "$MKINITCPIO_TMP"

if ! grep -Eq '^MODULES=.*nvidia.*nvidia_modeset.*nvidia_uvm.*nvidia_drm' "$MKINITCPIO_TMP"; then
  if grep -Eq '^MODULES=' "$MKINITCPIO_TMP"; then
    sed -Ei 's/^MODULES=\(([^)]*)\)/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINITCPIO_TMP"
  else
    printf '%s\n' 'MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' >> "$MKINITCPIO_TMP"
  fi
fi

grep -Eq '^MODULES=.*nvidia.*nvidia_modeset.*nvidia_uvm.*nvidia_drm' "$MKINITCPIO_TMP" || {
  log '[ERROR] Failed to produce a valid NVIDIA MODULES configuration.'
  exit 1
}
sudo cp -- "$MKINITCPIO_TMP" /etc/mkinitcpio.conf

if ! sudo test -f /etc/modprobe.d/nvidia.conf; then
  printf '%s\n' 'options nvidia_drm modeset=1 fbdev=1' | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null
elif ! sudo grep -Fq 'options nvidia_drm modeset=1 fbdev=1' /etc/modprobe.d/nvidia.conf; then
  printf '%s\n' 'options nvidia_drm modeset=1 fbdev=1' | sudo tee -a /etc/modprobe.d/nvidia.conf >/dev/null
fi

log '[ACTION] Rebuilding initramfs.'
sudo mkinitcpio -P 2>&1 | tee -a "$LOG"

if sudo test -f /etc/default/grub; then
  GRUB_TMP="$(mktemp)"
  sudo cp -- /etc/default/grub "$GRUB_TMP"

  grep -q 'nvidia-drm.modeset=1' "$GRUB_TMP" || \
    sed -Ei 's/^(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*)"/\1 nvidia-drm.modeset=1"/' "$GRUB_TMP"
  grep -q 'nvidia_drm.fbdev=1' "$GRUB_TMP" || \
    sed -Ei 's/^(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*)"/\1 nvidia_drm.fbdev=1"/' "$GRUB_TMP"

  grep -q 'nvidia-drm.modeset=1' "$GRUB_TMP" || { log '[ERROR] Failed to add NVIDIA DRM modeset option to GRUB.'; exit 1; }
  grep -q 'nvidia_drm.fbdev=1' "$GRUB_TMP" || { log '[ERROR] Failed to add NVIDIA fbdev option to GRUB.'; exit 1; }

  sudo cp -- "$GRUB_TMP" /etc/default/grub
  log '[ACTION] Regenerating GRUB configuration.'
  sudo grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tee -a "$LOG"
fi

if sudo test -f /boot/loader/loader.conf; then
  shopt -s nullglob
  entries=(/boot/loader/entries/*.conf)
  if ((${#entries[@]} == 0)); then
    log '[INFO] systemd-boot detected but no loader entries were found.'
  else
    for entry in "${entries[@]}"; do
      capture_file "$entry"

      tmp="$(mktemp)"
      sudo awk '
        /^options / {
          sub(/ nvidia-drm\.modeset=[^ ]*/, "")
          sub(/ nvidia_drm\.fbdev=[^ ]*/, "")
          print $0 " nvidia-drm.modeset=1 nvidia_drm.fbdev=1"
          next
        }
        { print }
      ' "$entry" > "$tmp"

      grep -Eq '^options .*nvidia-drm\.modeset=1.*nvidia_drm\.fbdev=1' "$tmp" || {
        rm -f -- "$tmp"
        log "[ERROR] Failed to prepare systemd-boot entry: $entry"
        exit 1
      }
      sudo cp -- "$tmp" "$entry"
      rm -f -- "$tmp"
    done
  fi
fi

trap - ERR
log '[OK] NVIDIA system integration completed.'

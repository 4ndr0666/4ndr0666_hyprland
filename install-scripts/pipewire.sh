#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# Pipewire and Pipewire Audio Stuff #


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_pipewire.log"
mkdir -p "$(dirname "$LOG")"
export LOG

source "$SCRIPT_DIR/core/packages.sh"

PIPEWIRE_PACKAGES=(
  pipewire
  wireplumber
  pipewire-audio
  pipewire-alsa
  pipewire-pulse
  sof-firmware
)

printf '%s\n' "[INFO] Disabling pulseaudio user units to avoid conflicts."
systemctl --user disable --now pulseaudio.socket pulseaudio.service >> "$LOG" 2>&1 || true

printf '%s\n' "[INFO] Installing PipeWire packages."
package_install "${PIPEWIRE_PACKAGES[@]}"

printf '%s\n' "[INFO] Activating PipeWire user services."
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
systemctl --user enable --now pipewire.service

printf '%s\n' "[OK] PipeWire installation and service setup completed."

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
if ! systemctl --user disable --now pulseaudio.socket pulseaudio.service >>"$LOG" 2>&1; then
  if systemctl --user is-enabled pulseaudio.socket pulseaudio.service >/dev/null 2>&1 || systemctl --user is-active pulseaudio.socket pulseaudio.service >/dev/null 2>&1; then
    printf '%s\n' "[ERROR] Failed to disable active/enabled PulseAudio user units." | tee -a "$LOG" >&2
    exit 1
  fi
  printf '%s\n' "[INFO] PulseAudio user units are already absent/inactive; continuing." | tee -a "$LOG"
fi

printf '%s\n' "[INFO] Installing PipeWire packages."
package_install "${PIPEWIRE_PACKAGES[@]}"

printf '%s\n' "[INFO] Activating PipeWire user services."
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
systemctl --user enable --now pipewire.service

printf '%s\n' "[OK] PipeWire installation and service setup completed."

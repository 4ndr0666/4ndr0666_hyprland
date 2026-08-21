#!/usr/bin/env bash
# 4ndr0666 Arch Linux / Hyprland installer entry point.
# This file owns orchestration only. Package mutations belong to core/packages.sh.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$ROOT/install-scripts"
LOG_DIR="$ROOT/Install-Logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/01-Hyprland-Install-Scripts-$(date +%d-%H%M%S).log"
export LOG

if ((EUID == 0)); then
  printf '[ERROR] Do not run this installer as root.\n' | tee -a "$LOG" >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  printf '[ERROR] Cannot determine operating system.\n' | tee -a "$LOG" >&2
  exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == arch ]] || { printf '[ERROR] This installer supports Arch Linux only.\n' >&2; exit 1; }

source "$SCRIPT_DIR/core/packages.sh"

if package_is_installed pulseaudio; then
  printf '[ERROR] PulseAudio is installed; remove it before continuing.\n' | tee -a "$LOG" >&2
  exit 1
fi

# The UI depends on whiptail; install it through the same package transaction
# primitive used by the rest of the installer.
if ! command -v whiptail >/dev/null 2>&1; then
  package_install libnewt
fi
package_install pciutils

execute_script() {
  local script="$1"
  local path="$SCRIPT_DIR/$script"
  [[ -f "$path" ]] || { printf '[ERROR] Missing installer module: %s\n' "$path" >&2; return 1; }
  chmod +x -- "$path"
  env "$path"
}

check_login_managers() {
  active_services=()
  local svc
  for svc in gdm.service gdm3.service lightdm.service lxdm.service; do
    if systemctl is-active --quiet "$svc"; then
      active_services+=("$svc")
    fi
  done
  ((${#active_services[@]} > 0))
}

printf '\n4ndr0666 Arch Linux Installation\n\n' | tee -a "$LOG"
whiptail --title '4ndr0666 Arch-Hyprland' \
  --msgbox 'Run a full system update and reboot before installation. VM users should enable 3D acceleration.' 12 72

if ! whiptail --title 'Proceed with Installation?' --yesno 'Proceed with the installation?' 7 50; then
  printf '[INFO] Installation cancelled.\n' | tee -a "$LOG"
  exit 0
fi

# Presets are data supplied by the caller; they are sourced only after the
# argument shape has been validated.
gtk_themes=OFF bluetooth=OFF thunar=OFF quickshell=OFF sddm=OFF sddm_theme=OFF
xdph=OFF zsh=OFF pokemon=OFF rog=OFF dots=OFF input_group=OFF nvidia=OFF nouveau=OFF
if [[ "${1:-}" == --preset && -n "${2:-}" ]]; then
  [[ -f "$2" ]] || { printf '[ERROR] Preset not found: %s\n' "$2" >&2; exit 1; }
  # shellcheck disable=SC1090
  source "$2"
fi

# AUR helper selection is retained as UI policy; installation itself remains
# delegated to the dedicated yay/paru module and package core.
aur_helper="$(package_aur_helper 2>/dev/null || true)"
if [[ -z "$aur_helper" ]]; then
  while true; do
    aur_helper="$(whiptail --title 'AUR Helper' --checklist \
      'Select exactly one AUR helper.' 12 60 2 \
      yay 'AUR helper yay' OFF \
      paru 'AUR helper paru' OFF \
      3>&1 1>&2 2>&3)" || exit 0
    aur_helper="${aur_helper//\"/}"
    [[ "$aur_helper" == yay || "$aur_helper" == paru ]] && break
    whiptail --msgbox 'Select exactly one AUR helper.' 8 50
  done
fi

nvidia_detected=false
if lspci | grep -qi nvidia; then nvidia_detected=true; fi
input_group_detected=false
if ! groups "$(id -un)" | grep -qw input; then input_group_detected=true; fi

options_command=(whiptail --title 'Select Options' --checklist 'Choose options to install or configure.' 28 85 20)
if [[ "$nvidia_detected" == true ]]; then
  options_command+=(nvidia 'Configure NVIDIA GPU' OFF nouveau 'Blacklist Nouveau' OFF)
fi
if [[ "$input_group_detected" == true ]]; then
  options_command+=(input_group 'Add user to input group' OFF)
fi
if ! check_login_managers; then
  options_command+=(sddm 'Install and configure SDDM' OFF sddm_theme 'Install additional SDDM theme' OFF)
fi
options_command+=(
  gtk_themes 'Install GTK themes' OFF
  bluetooth 'Configure Bluetooth' OFF
  thunar 'Install Thunar' OFF
  quickshell 'Install Quickshell' OFF
  xdph 'Install XDG desktop portal for Hyprland' OFF
  zsh 'Install zsh with Oh-My-Zsh' OFF
  pokemon 'Install Pokemon color scripts' OFF
  rog 'Install ASUS ROG packages' OFF
  dots 'Install pre-configured Hyprland dotfiles' OFF
)

while true; do
  selected_options="$("${options_command[@]}" 3>&1 1>&2 2>&3)" || exit 0
  selected_options="${selected_options//\"/}"
  [[ -n "$selected_options" ]] || { whiptail --msgbox 'Select at least one option.' 8 50; continue; }

  IFS=' ' read -r -a options <<< "$selected_options"
  dots_selected=false
  for option in "${options[@]}"; do [[ "$option" == dots ]] && dots_selected=true; done

  if [[ "$dots_selected" == false ]]; then
    whiptail --title 'Dotfiles' --yesno 'Continue without the pre-configured dotfiles?' 10 70 || continue
  fi

  confirm_message=$'Selected options:\n\n'
  for option in "${options[@]}"; do confirm_message+=" - $option\n"; done
  confirm_message+=$'\nProceed?'
  whiptail --title 'Confirm Choices' --yesno "$confirm_message" 25 80 && break
done

# Establish the base package state before any feature module executes.
execute_script 00-base.sh
execute_script pacman.sh

if [[ "$aur_helper" == yay ]]; then
  execute_script yay.sh
elif [[ "$aur_helper" == paru ]]; then
  execute_script paru.sh
fi

execute_script 01-hypr-pkgs.sh
execute_script pipewire.sh
execute_script fonts.sh
execute_script hyprland.sh

for option in "${options[@]}"; do
  case "$option" in
    sddm) execute_script sddm.sh ;;
    nvidia) execute_script nvidia.sh ;;
    nouveau) execute_script nvidia_nouveau.sh ;;
    gtk_themes) execute_script gtk_themes.sh ;;
    input_group) execute_script InputGroup.sh ;;
    quickshell) execute_script quickshell.sh ;;
    xdph) execute_script xdph.sh ;;
    bluetooth) execute_script bluetooth.sh ;;
    thunar) execute_script thunar.sh; execute_script thunar_default.sh ;;
    sddm_theme) execute_script sddm_theme.sh ;;
    zsh) execute_script zsh.sh ;;
    pokemon) execute_script zsh_pokemon.sh ;;
    rog) execute_script rog.sh ;;
    dots) execute_script dotfiles-main.sh ;;
    *) printf '[ERROR] Unknown option: %s\n' "$option" >&2; exit 1 ;;
  esac
done

if [[ ! -f "$HOME/.config/fastfetch/arch.png" ]]; then
  mkdir -p "$HOME/.config"
  cp -a -- "$ROOT/assets/fastfetch" "$HOME/.config/"
fi

execute_script 02-Final-Check.sh

if package_is_installed hyprland || package_is_installed hyprland-git; then
  printf '[OK] Hyprland is installed.\n' | tee -a "$LOG"
  printf '[INFO] A reboot is recommended.\n' | tee -a "$LOG"
else
  printf '[ERROR] Hyprland is not installed. Review Install-Logs.\n' | tee -a "$LOG" >&2
  exit 1
fi

#!/usr/bin/env bash
# 4ndr0666 Arch Linux / Hyprland installer entry point.
# Orchestration only: package mutation belongs to core/packages.sh.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$ROOT/install-scripts"
LOG_DIR="$ROOT/Install-Logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/01-Hyprland-Install-Scripts-$(date +%d-%H%M%S).log"
export LOG

((EUID != 0)) || { printf '[ERROR] Do not run this installer as root.\n' >&2; exit 1; }
[[ -r /etc/os-release ]] || { printf '[ERROR] Cannot determine operating system.\n' >&2; exit 1; }
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == arch ]] || { printf '[ERROR] This installer supports Arch Linux only.\n' >&2; exit 1; }

source "$SCRIPT_DIR/core/packages.sh"
package_is_installed pulseaudio && { printf '[ERROR] PulseAudio is installed; remove it first.\n' >&2; exit 1; }
command -v whiptail >/dev/null 2>&1 || package_install libnewt
package_install pciutils

execute_script() {
  local path="$SCRIPT_DIR/$1"
  [[ -f "$path" ]] || { printf '[ERROR] Missing installer module: %s\n' "$path" >&2; return 1; }
  chmod +x -- "$path"
  env "$path"
}

check_login_managers() {
  active_services=()
  local svc
  for svc in gdm.service gdm3.service lightdm.service lxdm.service; do
    systemctl is-active --quiet "$svc" && active_services+=("$svc")
  done
  ((${#active_services[@]} > 0))
}

whiptail --title '4ndr0666 Arch-Hyprland' --msgbox 'Run a full system update and reboot before installation. VM users should enable 3D acceleration.' 12 72
whiptail --title 'Proceed with Installation?' --yesno 'Proceed with the installation?' 7 50 || exit 0

gtk_themes=OFF bluetooth=OFF thunar=OFF quickshell=OFF sddm=OFF sddm_theme=OFF
xdph=OFF zsh=OFF pokemon=OFF rog=OFF dots=OFF input_group=OFF nvidia=OFF nouveau=OFF
if [[ "${1:-}" == --preset ]]; then
  [[ -n "${2:-}" && -f "$2" ]] || { printf '[ERROR] Invalid preset.\n' >&2; exit 1; }
  # shellcheck disable=SC1090
  source "$2"
fi

aur_helper="$(package_aur_helper 2>/dev/null || true)"
if [[ -z "$aur_helper" ]]; then
  while true; do
    aur_helper="$(whiptail --title 'AUR Helper' --checklist 'Select exactly one AUR helper.' 12 60 2 yay 'AUR helper yay' OFF paru 'AUR helper paru' OFF 3>&1 1>&2 2>&3)" || exit 0
    aur_helper="${aur_helper//\"/}"
    [[ "$aur_helper" == yay || "$aur_helper" == paru ]] && break
    whiptail --msgbox 'Select exactly one AUR helper.' 8 50
  done
fi

nvidia_detected=false
lspci | grep -qi nvidia && nvidia_detected=true
input_group_detected=false
groups "$(id -un)" | grep -qw input || input_group_detected=true

options_command=(whiptail --title 'Select Options' --checklist 'Choose options to install or configure.' 28 85 20)
if [[ "$nvidia_detected" == true ]]; then options_command+=(nvidia 'Configure NVIDIA GPU' OFF nouveau 'Blacklist Nouveau' OFF); fi
if [[ "$input_group_detected" == true ]]; then options_command+=(input_group 'Add user to input group' OFF); fi
if ! check_login_managers; then options_command+=(sddm 'Install and configure SDDM' OFF sddm_theme 'Install additional SDDM theme' OFF); fi
options_command+=(gtk_themes 'Install GTK themes' OFF bluetooth 'Configure Bluetooth' OFF thunar 'Install Thunar' OFF quickshell 'Install Quickshell' OFF xdph 'Install XDG desktop portal for Hyprland' OFF zsh 'Install zsh with Oh-My-Zsh' OFF pokemon 'Install Pokemon color scripts' OFF rog 'Install ASUS ROG packages' OFF dots 'Install pre-configured Hyprland dotfiles' OFF)

while true; do
  selected_options="$("${options_command[@]}" 3>&1 1>&2 2>&3)" || exit 0
  selected_options="${selected_options//\"/}"
  [[ -n "$selected_options" ]] || { whiptail --msgbox 'Select at least one option.' 8 50; continue; }
  IFS=' ' read -r -a options <<< "$selected_options"
  dots_selected=false
  for option in "${options[@]}"; do [[ "$option" == dots ]] && dots_selected=true; done
  [[ "$dots_selected" == true ]] || whiptail --title 'Dotfiles' --yesno 'Continue without the pre-configured dotfiles?' 10 70 || continue
  confirm_message=$'Selected options:\n\n'
  for option in "${options[@]}"; do confirm_message+=" - $option\n"; done
  confirm_message+=$'\nProceed?'
  whiptail --title 'Confirm Choices' --yesno "$confirm_message" 25 80 && break
done

execute_script 00-base.sh
execute_script pacman.sh
case "$aur_helper" in yay) execute_script yay.sh ;; paru) execute_script paru.sh ;; esac
execute_script 01-hypr-pkgs.sh
execute_script pipewire.sh
execute_script fonts.sh
execute_script hyprland.sh

for option in "${options[@]}"; do
  case "$option" in
    sddm) execute_script sddm.sh ;; nvidia) execute_script nvidia.sh ;; nouveau) execute_script nvidia_nouveau.sh ;;
    gtk_themes) execute_script gtk_themes.sh ;; input_group) execute_script InputGroup.sh ;; quickshell) execute_script quickshell.sh ;;
    xdph) execute_script xdph.sh ;; bluetooth) execute_script bluetooth.sh ;; thunar) execute_script thunar.sh; execute_script thunar_default.sh ;;
    sddm_theme) execute_script sddm_theme.sh ;; zsh) execute_script zsh.sh ;; pokemon) execute_script zsh_pokemon.sh ;; rog) execute_script rog.sh ;; dots) execute_script dotfiles-main.sh ;;
    *) printf '[ERROR] Unknown option: %s\n' "$option" >&2; exit 1 ;;
  esac
done

if [[ ! -f "$HOME/.config/fastfetch/arch.png" ]]; then mkdir -p "$HOME/.config"; cp -a -- "$ROOT/assets/fastfetch" "$HOME/.config/"; fi
execute_script 02-Final-Check.sh

if package_is_installed hyprland || package_is_installed hyprland-git; then
  printf '[OK] Hyprland is installed. A reboot is recommended.\n' | tee -a "$LOG"
else
  printf '[ERROR] Hyprland is not installed. Review Install-Logs.\n' | tee -a "$LOG" >&2
  exit 1
fi

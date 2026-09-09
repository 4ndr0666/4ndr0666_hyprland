#!/usr/bin/env bash
# === 4ndr0666 === #
# Main install/upgrade orchestrator. Component work lives in scripts/lib_*.sh.
set -Eeuo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$SOURCE_ROOT"
export COPY_TUI_BACKEND="${COPY_TUI_BACKEND:-basic}"

source "$SOURCE_ROOT/scripts/copy_menu.sh"
source "$SOURCE_ROOT/scripts/lib_backup.sh"
source "$SOURCE_ROOT/scripts/lib_detect.sh"
source "$SOURCE_ROOT/scripts/lib_prompts.sh"
source "$SOURCE_ROOT/scripts/lib_apps.sh"
source "$SOURCE_ROOT/scripts/lib_copy.sh"
source "$SOURCE_ROOT/scripts/lib_resolution.sh"
source "$SOURCE_ROOT/scripts/lib_waybar.sh"

readonly MIN_EXPRESS_VERSION="2.3.18"
readonly WALLPAPER_STATE="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
readonly WAYBAR_CONFIG="$HOME/.config/waybar/config"
readonly WAYBAR_STYLE="$HOME/.config/waybar/style/[Extra] Neon Circuit.css"
readonly WAYBAR_DESKTOP="$HOME/.config/waybar/configs/[TOP] Default"
readonly WAYBAR_LAPTOP="$HOME/.config/waybar/configs/[TOP] Default Laptop"

LOG=""
DOWNLOAD_DIR=""
DEPLOY_STAGE_DIR=""

cleanup() {
  local rc=$?
  if [[ -n "$DOWNLOAD_DIR" && -d "$DOWNLOAD_DIR" ]]; then
    rm -rf -- "$DOWNLOAD_DIR"
  fi
  if [[ -n "$DEPLOY_STAGE_DIR" && -d "$DEPLOY_STAGE_DIR" ]]; then
    rm -rf -- "$DEPLOY_STAGE_DIR"
  fi
  return "$rc"
}
trap cleanup EXIT INT TERM HUP

usage() {
  cat <<'EOF'
Usage: copy.sh [--upgrade] [--express-upgrade] [--help]

Options:
  --upgrade           Run the standard upgrade workflow.
  --express-upgrade   Run the upgrade workflow without optional restore prompts.
  -h, --help          Show this help message.
EOF
}

version_gte() {
  [[ "$1" == "$(printf '%s\n' "$1" "$2" | sort -V | tail -n1)" ]]
}

get_installed_dotfiles_version() {
  local hypr_dir="$HOME/.config/hypr"
  [[ -d "$hypr_dir" ]] || return 1
  find "$hypr_dir" -maxdepth 1 -type f -name 'v*.*.*' -printf '%f\n' 2>/dev/null \
    | sed 's/^v//' | sort -V | tail -n1
}

express_supported() {
  local current
  current="$(get_installed_dotfiles_version)" || return 1
  [[ -n "$current" ]] && version_gte "$current" "$MIN_EXPRESS_VERSION"
}

prepare_log() {
  local log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/4ndr0666-hyprland"
  mkdir -p "$log_dir"
  LOG="$log_dir/install-$(date +%d-%H%M%S)_dotfiles.log"
  : >"$LOG"
}

install_quickshell_config() {
  local destination="$HOME/.config/quickshell"
  local source="$SCRIPT_DIR/config/quickshell"
  local answer

  [[ -d "$source" ]] || return 0
  command -v qs >/dev/null 2>&1 || return 0

  if [[ ! -e "$destination" ]]; then
    mkdir -p "$(dirname "$destination")"
    cp -a -- "$source" "$destination"
  else
    printf '%s' '[ACTION] Overwrite existing Quickshell configuration? [y/N] ' >/dev/tty
    read -r answer </dev/tty
    case "$answer" in
      y|Y|yes|YES) replace_dir_transaction "$source" "$destination" "$LOG" ;;
      *) printf '%s\n' '[INFO] Existing Quickshell configuration retained.' | tee -a "$LOG" ;;
    esac
  fi

  rm -f -- "$destination/shell.qml"
  if [[ -d "$source/overview" && ! -d "$destination/overview" ]]; then
    cp -a -- "$source/overview" "$destination/"
  fi
}

configure_waybar_links() {
  local chassis_type answer
  local obsolete_present=0
  chassis_type="$(detect_waybar_config)"

  local obsolete_path
  for obsolete_path in \
    "$HOME/.config/waybar/configs/[TOP] Default" \
    "$HOME/.config/waybar/configs/[TOP] Default Laptop" \
    "$HOME/.config/waybar/configs/[BOT] Default" \
    "$HOME/.config/waybar/configs/[BOT] Default Laptop" \
    "$HOME/.config/waybar/configs/[TOP] Default (old v1)" \
    "$HOME/.config/waybar/configs/[TOP] Default Laptop (old v1)" \
    "$HOME/.config/waybar/configs/[TOP] Default (old v2)" \
    "$HOME/.config/waybar/configs/[TOP] Default Laptop (old v2)" \
    "$HOME/.config/waybar/configs/[TOP] Default (old v3)" \
    "$HOME/.config/waybar/configs/[TOP] Default Laptop (old v3)" \
    "$HOME/.config/waybar/configs/[TOP] Default (old v4)" \
    "$HOME/.config/waybar/configs/[TOP] Default Laptop (old v4)"; do
    if [[ -e "$obsolete_path" || -L "$obsolete_path" ]]; then
      obsolete_present=1
      break
    fi
  done

  if [[ -e "$WAYBAR_CONFIG" && ! -L "$WAYBAR_CONFIG" || -e "$HOME/.config/waybar/style.css" && ! -L "$HOME/.config/waybar/style.css" || "$obsolete_present" -eq 1 ]]; then
    printf '%s' '[ACTION] Manage Waybar symlinks and remove obsolete layouts? [y/N] ' >/dev/tty
    read -r answer </dev/tty
    case "$answer" in
      y|Y|yes|YES) ;;
      *)
        printf '%s\n' '[INFO] Existing Waybar state retained; skipping link transaction.' | tee -a "$LOG"
        return 0
        ;;
    esac
  fi

  waybar_link_transaction "$chassis_type" "$LOG"
}

apply_sddm_wallpaper() {
  local target='/usr/share/sddm/themes/simple_sddm_2/Backgrounds/default'
  local answer
  [[ -d '/usr/share/sddm/themes/simple_sddm_2' ]] || return 0
  [[ -f "$WALLPAPER_STATE" ]] || return 0
  [[ "$EXPRESS_MODE" -eq 1 ]] && return 0

  printf '%s' '[ACTION] Apply current wallpaper to SDDM? [y/N] ' >/dev/tty
  read -r answer </dev/tty
  case "$answer" in
    y|Y|yes|YES) sudo -n install -m 0644 -- "$WALLPAPER_STATE" "$target" ;;
    *) : ;;
  esac
}

offer_additional_wallpapers() {
  [[ "$EXPRESS_MODE" -eq 0 ]] || return 0
  local answer
  printf '%s' '[ACTION] Download the optional 1GB wallpaper bank? [y/N] ' >/dev/tty
  read -r answer </dev/tty
  case "$answer" in
    y|Y|yes|YES) ;;
    *) return 0 ;;
  esac

  DOWNLOAD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-wallpaper-bank.XXXXXX")"
  git clone --depth=1 --no-tags 'https://github.com/4ndr0666/Wallpaper-Bank.git' "$DOWNLOAD_DIR/Wallpaper-Bank"
  mkdir -p "$HOME/Pictures/wallpapers"
  cp -a -- "$DOWNLOAD_DIR/Wallpaper-Bank/wallpapers/." "$HOME/Pictures/wallpapers/"
}

RUN_MODE=""
UPGRADE_MODE=0
EXPRESS_MODE=0

while (($#)); do
  case "$1" in
    --upgrade) UPGRADE_MODE=1; RUN_MODE=upgrade ;;
    --express-upgrade) UPGRADE_MODE=1; EXPRESS_MODE=1; RUN_MODE=express ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%s\n' "[ERROR] Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

EXPRESS_SUPPORTED=0
if express_supported; then
  EXPRESS_SUPPORTED=1
fi
if [[ "$EXPRESS_MODE" -eq 1 && "$EXPRESS_SUPPORTED" -eq 0 ]]; then
  printf '%s\n' '[ERROR] Express upgrade requires the installed dotfiles version to meet the minimum supported version.' >&2
  exit 2
fi

if [[ -z "$RUN_MODE" ]]; then
  show_copy_menu "$EXPRESS_SUPPORTED" || exit 0
  case "${COPY_MENU_CHOICE,,}" in
    install) RUN_MODE=install ;;
    upgrade) RUN_MODE=upgrade; UPGRADE_MODE=1 ;;
    express) RUN_MODE=express; UPGRADE_MODE=1; EXPRESS_MODE=1 ;;
    quit) exit 0 ;;
    *) printf '%s\n' '[ERROR] Invalid workflow selection.' >&2; exit 2 ;;
  esac
fi

if [[ "$EUID" -eq 0 ]]; then
  printf '%s\n' '[ERROR] copy.sh must not be executed as root.' >&2
  exit 1
fi

prepare_log
xdg-user-dirs-update 2>&1 | tee -a "$LOG"
printf '%s\n' "[INFO] Selected workflow: $RUN_MODE" | tee -a "$LOG"

DEPLOY_STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-copy-stage.XXXXXX")"
cp -a -- "$SOURCE_ROOT/config" "$DEPLOY_STAGE_DIR/"
cp -a -- "$SOURCE_ROOT/wallpapers" "$DEPLOY_STAGE_DIR/"
SCRIPT_DIR="$DEPLOY_STAGE_DIR"
cd -- "$DEPLOY_STAGE_DIR"

# Environment-specific mutations are confined to the ephemeral stage.
detect_nvidia_adjust "$LOG"
detect_vm_adjust "$LOG"
detect_nixos_adjust "$LOG"

layout="$(prompt_detect_layout)"
prompt_keyboard_layout "$layout" "$LOG"
enable_asusctl "$LOG"
enable_blueman "$LOG"
enable_quickshell "$LOG"
ensure_keybinds_init "$LOG"
choose_default_editor "$LOG"
resolution="$(prompt_resolution_choice)"
prompt_clock_12h "$LOG"
prompt_express_upgrade "$EXPRESS_SUPPORTED" "$LOG"

INSTALLED_VERSION_AT_START="$(get_installed_dotfiles_version || true)"

copy_phase1 "$LOG"
copy_waybar "$LOG"
copy_phase2 "$LOG"
install_quickshell_config
apply_resolution_profile "$resolution"
restore_hypr_assets "$LOG" "$EXPRESS_MODE"
restore_user_configs "$LOG" "$EXPRESS_MODE" "$INSTALLED_VERSION_AT_START"
restore_user_scripts "$LOG" "$EXPRESS_MODE"
restore_hypr_files "$LOG" "$EXPRESS_MODE"

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || printf '%s' "$HOME/Pictures")"
mkdir -p "$PICTURES_DIR/wallpapers"
cp -a -- "$SCRIPT_DIR/wallpapers/." "$PICTURES_DIR/wallpapers/"

for executable_dir in "$HOME/.config/hypr/scripts" "$HOME/.config/hypr/UserScripts"; do
  if [[ -d "$executable_dir" ]]; then
    find "$executable_dir" -maxdepth 1 -type f -exec chmod +x -- {} +
  fi
done
chmod +x -- "$HOME/.config/hypr/initial-boot.sh"

configure_waybar_links
apply_sddm_wallpaper
offer_additional_wallpapers

if [[ "$EXPRESS_MODE" -eq 1 ]]; then
  cleanup_backups auto "$LOG"
else
  cleanup_backups prompt "$LOG"
fi

if [[ -f "$WALLPAPER_STATE" ]]; then
  "$HOME/.config/hypr/scripts/WallustAwww.sh" "$WALLPAPER_STATE" | tee -a "$LOG"
else
  printf '%s\n' '[ERROR] Current wallpaper state is missing; refusing to generate an invalid Wallust palette.' >&2
  exit 1
fi

printf '%s\n' '[OK] 4ndr0666 Hyprland configuration installed successfully.' | tee -a "$LOG"

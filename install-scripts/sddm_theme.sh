#!/usr/bin/env bash
set -Eeuo pipefail

source_theme="https://github.com/4ndr0666/simple-sddm-2.git"
theme_name="simple_sddm_2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core/ui.sh"

PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_sddm_theme.log"
THEME_ROOT="/usr/share/sddm/themes"
THEME_DEST="$THEME_ROOT/$theme_name"
SDDM_CONF="/etc/sddm.conf"
TRANSACTION_DIR="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-sddm-theme.XXXXXX")"
STAGED_THEME="$TRANSACTION_DIR/$theme_name"
THEME_BACKUP="$TRANSACTION_DIR/theme-backup"
SDDM_BACKUP="$TRANSACTION_DIR/sddm.conf.backup"
SDDM_NEW="$TRANSACTION_DIR/sddm.conf.new"
THEME_WAS_PRESENT=0
SDDM_WAS_PRESENT=0
COMMITTED=0
CLEANUP_FAILED=0

cleanup() {
  local rc=$?
  if ((COMMITTED == 0)); then
    if ((THEME_WAS_PRESENT)); then
      if [[ -d "$THEME_BACKUP" && ! -e "$THEME_DEST" ]]; then
        sudo -n mv -- "$THEME_BACKUP" "$THEME_DEST" || CLEANUP_FAILED=1
      fi
    elif [[ -e "$THEME_DEST" ]]; then
      sudo -n rm -rf -- "$THEME_DEST" || CLEANUP_FAILED=1
    fi
    if ((SDDM_WAS_PRESENT)); then
      if [[ -f "$SDDM_BACKUP" ]]; then
        sudo -n install -m 0644 -- "$SDDM_BACKUP" "$SDDM_CONF" || CLEANUP_FAILED=1
      fi
    elif [[ -e "$SDDM_CONF" ]]; then
      sudo -n rm -f -- "$SDDM_CONF" || CLEANUP_FAILED=1
    fi
  fi
  sudo -n rm -rf -- "$TRANSACTION_DIR" || CLEANUP_FAILED=1
  if ((CLEANUP_FAILED)); then
    printf '%s\n' '[ERROR] SDDM theme transaction cleanup failed.' >&2
    rc=1
  fi
  return "$rc"
}
trap cleanup EXIT INT TERM HUP

sudo -v
mkdir -p -- "$(dirname -- "$LOG")"

printf '%s\n' "${NOTE} Installing ${SKY_BLUE}Additional SDDM Theme${RESET}"

git clone --depth 1 --no-tags "$source_theme" "$STAGED_THEME" 2>&1 | tee -a "$LOG"
[[ -d "$STAGED_THEME/Backgrounds/default" ]] || {
  printf '%s\n' '[ERROR] Staged SDDM theme is incomplete.' >&2
  exit 1
}
[[ -f "$PARENT_DIR/assets/sddm.png" ]] || {
  printf '%s\n' '[ERROR] Required SDDM background asset is missing.' >&2
  exit 1
}

if [[ -d "$THEME_DEST" ]]; then
  THEME_WAS_PRESENT=1
  sudo -n cp -a -- "$THEME_DEST" "$THEME_BACKUP"
fi

if [[ -f "$SDDM_CONF" ]]; then
  SDDM_WAS_PRESENT=1
  sudo -n cp -a -- "$SDDM_CONF" "$SDDM_BACKUP"
fi

if ((SDDM_WAS_PRESENT)); then
  sudo -n cp -a -- "$SDDM_CONF" "$SDDM_NEW"
else
  : >"$SDDM_NEW"
fi

if grep -q '^\[Theme\]' "$SDDM_NEW"; then
  if grep -q '^Current=' "$SDDM_NEW"; then
    sed -i "s/^Current=.*/Current=$theme_name/" "$SDDM_NEW"
  else
    sed -i "/^\[Theme\]/a Current=$theme_name" "$SDDM_NEW"
  fi
else
  printf '\n[Theme]\nCurrent=%s\n' "$theme_name" >>"$SDDM_NEW"
fi

if grep -q '^\[General\]' "$SDDM_NEW"; then
  if grep -q '^\s*InputMethod=' "$SDDM_NEW"; then
    sed -i '/^\[General\]/,/^\[/{s/^\s*InputMethod=.*/InputMethod=qtvirtualkeyboard/}' "$SDDM_NEW"
  else
    sed -i '/^\[General\]/a InputMethod=qtvirtualkeyboard' "$SDDM_NEW"
  fi
else
  printf '\n[General]\nInputMethod=qtvirtualkeyboard\n' >>"$SDDM_NEW"
fi

grep -q '^Current=' "$SDDM_NEW"
grep -q '^InputMethod=qtvirtualkeyboard$' "$SDDM_NEW"

if ((THEME_WAS_PRESENT)); then
  sudo -n mv -- "$THEME_DEST" "$THEME_BACKUP"
fi
sudo -n mv -- "$STAGED_THEME" "$THEME_DEST"
sudo -n install -m 0644 -- "$PARENT_DIR/assets/sddm.png" "$THEME_DEST/Backgrounds/default/sddm.png"
sudo -n install -m 0644 -- "$SDDM_NEW" "$SDDM_CONF"

COMMITTED=1
printf '%s\n' "${OK} SDDM theme transaction committed." | tee -a "$LOG"

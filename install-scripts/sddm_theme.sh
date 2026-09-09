#!/usr/bin/env bash
set -Eeuo pipefail

source_theme="https://github.com/achrefbenmbarek1/terminal-inspired-sddm-theme.git"
theme_name="terminal-inspired"
SDDM_THEME_REPOSITORY_REVISION="e0691c4f3a3cff22a3635045902b9fc949d6bbf5"
GIT_COMMAND_TIMEOUT="${GIT_COMMAND_TIMEOUT:-900}"
[[ "$GIT_COMMAND_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || { printf '%s\n' '[ERROR] GIT_COMMAND_TIMEOUT must be a positive integer.' >&2; exit 1; }
command -v timeout >/dev/null 2>&1 || { printf '%s\n' '[ERROR] timeout is required for bounded SDDM dependency operations.' >&2; exit 1; }
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
SDDM_MODE=""
COMMITTED=0
CLEANUP_FAILED=0

cleanup() {
  local rc=$?
  if ((COMMITTED == 0)); then
    if ((THEME_WAS_PRESENT)); then
      if [[ -e "$THEME_DEST" || -L "$THEME_DEST" ]]; then
        sudo -n rm -rf -- "$THEME_DEST" || CLEANUP_FAILED=1
      fi
      if [[ -e "$THEME_BACKUP" || -L "$THEME_BACKUP" ]]; then
        sudo -n mv -- "$THEME_BACKUP" "$THEME_DEST" || CLEANUP_FAILED=1
      fi
    elif [[ -e "$THEME_DEST" || -L "$THEME_DEST" ]]; then
      sudo -n rm -rf -- "$THEME_DEST" || CLEANUP_FAILED=1
    fi
    if ((SDDM_WAS_PRESENT)); then
      if [[ -e "$SDDM_BACKUP" || -L "$SDDM_BACKUP" ]]; then
        sudo -n rm -f -- "$SDDM_CONF" || CLEANUP_FAILED=1
        sudo -n cp -a -- "$SDDM_BACKUP" "$SDDM_CONF" || CLEANUP_FAILED=1
      fi
    elif [[ -e "$SDDM_CONF" || -L "$SDDM_CONF" ]]; then
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

timeout --signal=TERM --kill-after=10s "$GIT_COMMAND_TIMEOUT" git clone --filter=blob:none --no-checkout --no-tags "$source_theme" "$STAGED_THEME" 2>>"$LOG"
timeout --signal=TERM --kill-after=10s "$GIT_COMMAND_TIMEOUT" git -C "$STAGED_THEME" checkout --detach "$SDDM_THEME_REPOSITORY_REVISION" >>"$LOG" 2>&1
ACTUAL_REVISION="$(git -C "$STAGED_THEME" rev-parse HEAD)"
[[ "$ACTUAL_REVISION" == "$SDDM_THEME_REPOSITORY_REVISION" ]] || {
  printf '%s\n' '[ERROR] Staged SDDM theme revision verification failed.' >&2
  exit 1
}
[[ -f "$STAGED_THEME/Main.qml" ]] || {
  printf '%s\n' '[ERROR] Staged SDDM theme is incomplete: Main.qml is missing.' >&2
  exit 1
}
[[ -f "$STAGED_THEME/theme.conf" ]] || {
  printf '%s\n' '[ERROR] Staged SDDM theme is incomplete: theme.conf is missing.' >&2
  exit 1
}
[[ -x "$STAGED_THEME/sessionsDetector.sh" ]] || {
  printf '%s\n' '[ERROR] Staged SDDM theme is incomplete: sessionsDetector.sh is not executable.' >&2
  exit 1
}
timeout --signal=TERM --kill-after=10s "$GIT_COMMAND_TIMEOUT" bash -c 'cd "$1" && ./sessionsDetector.sh' _ "$STAGED_THEME" >>"$LOG" 2>&1
[[ -s "$STAGED_THEME/sessions.txt" ]] || {
  printf '%s\n' '[ERROR] SDDM session discovery produced no sessions.txt.' >&2
  exit 1
}
timeout --signal=TERM --kill-after=10s "$GIT_COMMAND_TIMEOUT" git -C "$STAGED_THEME" clean -fdx >>"$LOG" 2>&1
rm -rf -- "$STAGED_THEME/.git"
[[ ! -e "$STAGED_THEME/.git" ]] || {
  printf '%s\n' '[ERROR] Failed to remove SDDM dependency metadata before deployment.' >&2
  exit 1
}

if [[ -e "$THEME_DEST" || -L "$THEME_DEST" ]]; then
  THEME_WAS_PRESENT=1
  sudo -n cp -a -- "$THEME_DEST" "$THEME_BACKUP"
fi

if [[ -f "$SDDM_CONF" ]]; then
  SDDM_WAS_PRESENT=1
  SDDM_MODE="$(stat -c '%a' -- "$SDDM_CONF")"
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
sudo -n install -m 0644 -- "$SDDM_NEW" "$SDDM_CONF"
if [[ -n "$SDDM_MODE" ]]; then
  sudo -n chmod -- "$SDDM_MODE" "$SDDM_CONF"
fi

COMMITTED=1
printf '%s\n' "${OK} SDDM theme transaction committed." | tee -a "$LOG"

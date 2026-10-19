#!/usr/bin/env bash
# === 4ndr0666 === #
# App enablement and editor selection helpers.



enable_asusctl() {
  local log="$1"
  if command -v asusctl >/dev/null 2>&1; then
    append_startup_command "rog-control-center"
    printf '%s\n' '[INFO] Added ROG Control Center to Lua startup.' | tee -a "$log"
  fi
}

enable_blueman() {
  local log="$1"
  if command -v blueman-applet >/dev/null 2>&1; then
    append_startup_command "blueman-applet"
    printf '%s\n' '[INFO] Added Blueman applet to Lua startup.' | tee -a "$log"
  fi
}

enable_quickshell() {
  local log="$1"
  if command -v qs >/dev/null 2>&1; then
    append_startup_command "qs"
    printf '%s\n' "${INFO:-[INFO]} Quickshell detected - enabling in startup" | tee -a "$log"
  fi
}

ensure_keybinds_init() {
  local log="$1"
  append_startup_expression \
    "KeybindsLayoutInit.sh" \
    'os.getenv("HOME") .. "/.config/hypr/scripts/KeybindsLayoutInit.sh"'
  printf '%s\n' "${INFO:-[INFO]} Ensured KeybindsLayoutInit.sh is reachable from Lua startup." | tee -a "$log"
}
install_terminal_configs() {
  local log="$1"

  local GHOSTTY_SRC="config/ghostty/ghostty.config"
  local GHOSTTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
  local GHOSTTY_DEST="$GHOSTTY_DIR/config"
  if [ -f "$GHOSTTY_SRC" ]; then
    mkdir -p "$GHOSTTY_DIR"
    install -m 0644 "$GHOSTTY_SRC" "$GHOSTTY_DEST" 2>&1 | tee -a "$log"
    if [ -f "$GHOSTTY_DIR/wallust.conf" ]; then
      if ! sed -i -E 's/^(\s*palette\s*=\s*)([0-9]{1,2}):/\1\2=/' "$GHOSTTY_DIR/wallust.conf"; then
        printf '%s\n' "${ERROR:-[ERROR]} - Failed to normalize Ghostty wallust palette." | tee -a "$log" >&2
        return 1
      fi
    fi
  else
    echo "${ERROR:-[ERROR]} -$GHOSTTY_SRC not found; skipping Ghostty config install." 2>&1 | tee -a "$log"
  fi

  local WEZTERM_SRC="config/wezterm/wezterm.lua"
  local WEZTERM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wezterm"
  local WEZTERM_DEST="$WEZTERM_DIR/wezterm.lua"
  if [ -f "$WEZTERM_SRC" ]; then
    mkdir -p "$WEZTERM_DIR"
    install -m 0644 "$WEZTERM_SRC" "$WEZTERM_DEST" 2>&1 | tee -a "$log"
  else
    echo "${ERROR:-[ERROR]} -$WEZTERM_SRC not found; skipping WezTerm config install." 2>&1 | tee -a "$log"
  fi
}

choose_default_editor() {
  local log="$1"
  local editor_set=0
  update_editor() {
    local editor="$1"
    local defaults="config/hypr/UserConfigs/01-UserDefaults.lua"
    local tmp
    local matches

    [[ "$editor" == nvim || "$editor" == vim ]] || {
      printf '[ERROR] Unsupported editor value: %s\n' "$editor" >&2
      return 2
    }
    [[ -f "$defaults" ]] || {
      printf '[ERROR] Required Lua defaults module is missing: %s\n' "$defaults" >&2
      return 1
    }
    matches="$(awk '/^[[:space:]]*hl\.env\(\042EDITOR\042, \042[^\042]+\042\)/ { count++ } END { print count + 0 }' "$defaults")" || return 1
    [[ "$matches" -eq 1 ]] || {
      printf '[ERROR] Expected exactly one EDITOR declaration in %s; found %s.\n' "$defaults" "$matches" >&2
      return 1
    }

    tmp="$(mktemp --tmpdir="$(dirname -- "$defaults")" '.01-UserDefaults.lua.XXXXXX')" || return 1
    if ! {
      sed -E 's/hl\.env\("EDITOR", "[^"]+"\)/hl.env("EDITOR", "'"$editor"'")/' "$defaults" >"$tmp" &&
        chmod --reference="$defaults" "$tmp" &&
        mv -- "$tmp" "$defaults"
    }; then
      rm -f -- "$tmp"
      return 1
    fi
    printf '%s\n' "${OK:-[OK]} Default editor set to ${MAGENTA:-}$editor${RESET:-}." | tee -a "$log"
  }
  if command -v nvim &>/dev/null; then
    printf '%s\n' "${INFO:-[INFO]} ${MAGENTA:-}neovim${RESET:-} is detected as installed"
    if ! read -r -p "${CAT:-[ACTION]} Do you want to make ${MAGENTA:-}neovim${RESET:-} the default editor? (y/N): " EDITOR_CHOICE </dev/tty; then
      :
    elif [[ "$EDITOR_CHOICE" == "y" || "$EDITOR_CHOICE" == "Y" ]]; then
      update_editor "nvim"
      editor_set=1
    fi
  fi
  printf "\n"
  if [[ "$editor_set" -eq 0 ]] && command -v vim &>/dev/null; then
    printf '%s\n' "${INFO:-[INFO]} ${MAGENTA:-}vim${RESET:-} is detected as installed"
    if read -r -p "${CAT:-[ACTION]} Do you want to make ${MAGENTA:-}vim${RESET:-} the default editor? (y/N): " EDITOR_CHOICE </dev/tty; then
      if [[ "$EDITOR_CHOICE" == "y" || "$EDITOR_CHOICE" == "Y" ]]; then
        update_editor "vim"
        editor_set=1
      fi
    fi
  fi
}
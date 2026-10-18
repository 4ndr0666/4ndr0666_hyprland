#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# Ensure keyboard layout switching bindings and initial layout state are active.
# Native Lua bindings in configs/Keybinds.lua own ALT_L+SHIFT_L and SHIFT_L+ALT_L;
# this startup helper preserves the Startup_Apps.lua initialization contract.

set -Eeuo pipefail

SCRIPTS_DIR="$HOME/.config/hypr/scripts"
KEYBINDS_LUA="$HOME/.config/hypr/configs/Keybinds.lua"

if [[ -f "$KEYBINDS_LUA" ]] && grep -Fq 'KeyboardLayout.sh switch' "$KEYBINDS_LUA"; then
    exit 0
fi

if command -v hyprctl >/dev/null 2>&1 && [[ -x "$SCRIPTS_DIR/KeyboardLayout.sh" ]]; then
    hyprctl dispatch "hl.bind("ALT_L + SHIFT_L", hl.dsp.exec_cmd("$SCRIPTS_DIR/KeyboardLayout.sh switch"), { locked = true, non_consuming = true, description = "switch keyboard layout globally" })" >/dev/null 2>&1 || true
fi

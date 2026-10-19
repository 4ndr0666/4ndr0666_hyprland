#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# KeybindsLayoutInit.sh — Initialize runtime keyboard layout switch bindings for Hyprland 0.55+ Lua.

set -Eeuo pipefail

SCRIPTS_DIR="${HOME}/.config/hypr/scripts"

if [[ -x "$SCRIPTS_DIR/Tak0-Per-Window-Switch.sh" ]]; then
    "$SCRIPTS_DIR/Tak0-Per-Window-Switch.sh" >/dev/null 2>&1 &
fi

if command -v hyprctl >/dev/null 2>&1 && [[ -x "$SCRIPTS_DIR/KeyboardLayout.sh" ]]; then
    hyprctl dispatch "hl.bind(\"ALT_L + SHIFT_L\", hl.dsp.exec_cmd(\"$SCRIPTS_DIR/KeyboardLayout.sh switch\"), { locked = true, non_consuming = true, description = \"switch keyboard layout globally\" })" >/dev/null 2>&1 || true
fi

exit 0

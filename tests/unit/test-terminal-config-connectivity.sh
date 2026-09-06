#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KEYBINDS="$ROOT/config/hypr/configs/Keybinds.lua"
APPS="$ROOT/scripts/lib_apps.sh"
COPY="$ROOT/scripts/lib_copy.sh"
KITTY="$ROOT/config/kitty/kitty.conf"
GHOSTTY="$ROOT/config/ghostty/ghostty.config"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

for file in "$KEYBINDS" "$APPS" "$COPY" "$KITTY" "$GHOSTTY"; do
  [[ -f "$file" ]] || fail "required terminal integration file is missing: $file"
done

grep -Fq 'local dirs=(fastfetch kitty rofi swaync)' "$COPY" || fail "Kitty is no longer part of transactional configuration deployment"
grep -Fq 'install_terminal_configs "$log"' "$COPY" || fail "terminal-specific deployment edge is missing"
grep -Fq 'local GHOSTTY_SRC="config/ghostty/ghostty.config"' "$APPS" || fail "Ghostty source authority is missing"
grep -Fq 'local GHOSTTY_DEST="$GHOSTTY_DIR/config"' "$APPS" || fail "Ghostty destination contract is missing"
grep -Fq 'hl.bind(mainMod .. " + Return"' "$KEYBINDS" || fail "default terminal keybind is missing"
grep -Fq 'local term = _G.user_defaults' "$KEYBINDS" || fail "terminal selection is disconnected from user defaults"
grep -Fq 'font_size' "$KITTY" || fail "Kitty configuration has no terminal runtime settings"
grep -Fq 'font-family' "$GHOSTTY" || grep -Fq 'font-size' "$GHOSTTY" || fail "Ghostty configuration has no terminal runtime settings"

printf 'PASS: Kitty and Ghostty sources remain connected to deployment and terminal selection\n'

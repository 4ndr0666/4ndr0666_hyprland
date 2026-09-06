#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KEYBINDS="$ROOT/config/hypr/configs/Keybinds.lua"
ROFI="$ROOT/config/rofi/config.rasi"
THEME="$ROOT/config/rofi/themes/saint-rofi.rasi"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

[[ -f "$KEYBINDS" ]] || fail "authoritative Lua keybind source is missing"
[[ -f "$ROFI" ]] || fail "Rofi root configuration is missing"
[[ -f "$THEME" ]] || fail "Rofi default theme is missing"

grep -Fq 'hl.bind(mainMod .. " + D",' "$KEYBINDS" || fail "application-launcher keybind is missing"
grep -Fq 'rofi -show drun' "$KEYBINDS" || fail "launcher keybind does not invoke Rofi"
grep -Fq '@import "~/.config/rofi/0-shared-fonts.rasi"' "$ROFI" || fail "Rofi root config is disconnected from shared fonts"
grep -Fq '@theme "~/.config/rofi/themes/saint-rofi.rasi"' "$ROFI" || fail "Rofi root config is disconnected from its authoritative theme"
grep -Fq 'modi:' "$THEME" || fail "authoritative Rofi theme has no runtime mode configuration"

printf 'PASS: Rofi keybind, root configuration, and theme form a live deployment chain\n'

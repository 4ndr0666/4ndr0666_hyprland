#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WAYBAR_CONFIG="$ROOT/config/waybar/config"
WAYBAR_STYLE="$ROOT/config/waybar/style.css"
ROFI_STATE="$ROOT/config/rofi/.current_wallpaper"
KEYBINDS="$ROOT/config/hypr/UserConfigs/UserKeybinds.lua"

[[ -L "$WAYBAR_CONFIG" ]] || { printf '[FAIL] Waybar config must remain a repository-relative symlink.\n' >&2; exit 1; }
[[ -L "$WAYBAR_STYLE" ]] || { printf '[FAIL] Waybar style must remain a repository-relative symlink.\n' >&2; exit 1; }
[[ "$(readlink -- "$WAYBAR_CONFIG")" == 'configs/[TOP] Simple' ]] || { printf '[FAIL] Waybar config contains a machine-local target.\n' >&2; exit 1; }
[[ "$(readlink -- "$WAYBAR_STYLE")" == 'style/[Colored] Translucent.css' ]] || { printf '[FAIL] Waybar style contains a machine-local target.\n' >&2; exit 1; }
[[ ! -e "$ROFI_STATE" ]] || { printf '[FAIL] Runtime wallpaper state must not be committed under config/rofi.\n' >&2; exit 1; }
! grep -R -n -F --exclude='test-runtime-path-integrity.sh' '/home/ja' "$ROOT/config" >/dev/null
! grep -R -n -F '/home/git/clone/4ndr0666/' "$ROOT/config" >/dev/null
! grep -Fq 'dorkmaster' "$KEYBINDS"

printf '[PASS] repository config contains no machine-local runtime paths.\n'

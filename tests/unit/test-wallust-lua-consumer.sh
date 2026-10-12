#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/config/hypr/UserConfigs/UserDecorations.lua"

[[ -f "$FILE" ]] || { printf '[FAIL] Wallust Lua consumer is missing.\n' >&2; exit 1; }

# The active Wallust target is configured in wallust.toml as .conf, not .lua.
grep -Fq 'local color_file_path = home .. "/.config/hypr/wallust/wallust-hyprland.conf"' "$FILE"
grep -Fq 'if key and val and not val:match("{") then' "$FILE"
grep -Fq 'local c12 = wallust_colors["color12"] or "rgba(33ccffee)"' "$FILE"
grep -Fq 'local c10 = wallust_colors["color10"] or "rgba(595959aa)"' "$FILE"
grep -Fq 'local c15 = wallust_colors["color15"] or "rgba(ffffffee)"' "$FILE"
grep -Fq 'local c0  = wallust_colors["color0"]  or "rgba(000000aa)"' "$FILE"

# Preserve the active decoration contract and reject the stale Lua target.
grep -Fq 'hl.config({' "$FILE"
! grep -Fq 'wallust-hyprland.lua' "$FILE"

printf '%s\n' 'Wallust Lua consumer path/template/fallback contract: PASS'

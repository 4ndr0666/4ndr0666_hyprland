#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/config/hypr/UserConfigs/UserDecorations.lua"

[[ -f "$FILE" ]] || { printf '[FAIL] Wallust Lua consumer is missing.\n' >&2; exit 1; }

grep -Fq 'assert(io.open(color_file_path, "r"), "Wallust color provider is unavailable:' "$FILE"
grep -Fq 'local required_colors = { "color0", "color10", "color12", "color15" }' "$FILE"
grep -Fq 'assert(wallust_colors[key], "Wallust color provider is incomplete: missing " .. key)' "$FILE"

! grep -Fq 'or "rgba(33ccffee)"' "$FILE"
! grep -Fq 'or "rgba(595959aa)"' "$FILE"
! grep -Fq 'or "rgba(ffffffee)"' "$FILE"
! grep -Fq 'or "rgba(000000aa)"' "$FILE"

printf '%s\n' 'Wallust Lua consumer fail-closed boundary: PASS'

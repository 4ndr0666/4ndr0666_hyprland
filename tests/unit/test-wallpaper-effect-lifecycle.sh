#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/hypr/UserScripts/WallpaperEffects.sh"

[[ -f "$SCRIPT" ]] || { printf '%s\n' 'missing WallpaperEffects.sh' >&2; exit 1; }
grep -Eq '^set -Eeuo pipefail$' "$SCRIPT" || { printf '%s\n' 'WallpaperEffects.sh lacks strict shell lifecycle semantics' >&2; exit 1; }
grep -Eq '^trap cleanup EXIT$' "$SCRIPT" || { printf '%s\n' 'wallpaper temporary state lacks unconditional cleanup' >&2; exit 1; }
grep -Eq 'tmp_output=.*mktemp' "$SCRIPT" || { printf '%s\n' 'wallpaper output is not staged in temporary state' >&2; exit 1; }
grep -Eq 'mv -f -- "\$tmp_output" "\$wallpaper_output"' "$SCRIPT" || { printf '%s\n' 'wallpaper output is not committed atomically' >&2; exit 1; }
if grep -Eq 'awww img .*&|wallust run .*&' "$SCRIPT"; then
  printf '%s\n' 'authoritative wallpaper operations run detached without lifecycle observation' >&2
  exit 1
fi
if grep -Eq 'pidof rofi|pkill rofi' "$SCRIPT"; then
  printf '%s\n' 'wallpaper launcher uses brittle preflight/process killing' >&2
  exit 1
fi
grep -Eq 'hyprctl monitors -j' "$SCRIPT" || { printf '%s\n' 'focused monitor discovery is missing' >&2; exit 1; }
grep -Eq 'jq -er' "$SCRIPT" || { printf '%s\n' 'focused monitor discovery does not fail loudly' >&2; exit 1; }
grep -Eq 'Current wallpaper is missing' "$SCRIPT" || { printf '%s\n' 'missing wallpaper input is not surfaced' >&2; exit 1; }
grep -Eq 'Wallpaper effect Rofi theme is missing' "$SCRIPT" || { printf '%s\n' 'missing Rofi theme is not surfaced' >&2; exit 1; }

printf '%s\n' 'Wallpaper effect lifecycle boundary: PASS'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COPY="$ROOT/copy.sh"
LIB="$ROOT/scripts/lib_copy.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

[[ -d "$ROOT/assets" ]] || fail "asset source tree is missing"
[[ -d "$ROOT/wallpapers" ]] || fail "wallpaper source tree is missing"
[[ -f "$LIB" ]] || fail "copy helper is missing"

grep -Fq 'PICTURES_DIR=' "$COPY" || fail "wallpaper destination resolution is missing"
grep -Fq 'mkdir -p "$PICTURES_DIR/wallpapers"' "$COPY" || fail "wallpaper destination creation is missing"
grep -Fq 'cp -a -- "$SCRIPT_DIR/wallpapers/." "$PICTURES_DIR/wallpapers/"' "$COPY" || fail "wallpaper deployment edge is missing"
grep -Fq 'restore_hypr_assets' "$COPY" || fail "Hyprland asset restoration edge is missing"
grep -Fq 'local wallpaper_backup="$backup_hypr_path/wallpaper_effects"' "$LIB" || fail "wallpaper-effect asset preservation edge is missing"

printf 'PASS: repository assets and wallpapers have explicit deployment and preservation edges\n'

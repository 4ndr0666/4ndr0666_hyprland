#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/home/.local/share/themes/Personal-Dark" "$tmp/home/.local/share/icons/Personal-Dark-Icons" "$tmp/bin"
export HOME="$tmp/home" XDG_DATA_HOME="$tmp/home/.local/share" CAPTURE="$tmp/calls"
cat > "$tmp/bin/gsettings" <<'STUB'
#!/bin/bash
[[ $# == 4 && $1 == set && $2 == org.gnome.desktop.interface ]] || exit 42
printf '%s|%s\n' "$3" "$4" >> "$CAPTURE"
STUB
chmod +x "$tmp/bin/gsettings"
export PATH="$tmp/bin:$PATH"
# Exercise the actual function, without invoking wallpaper or session changes.
sed -n '/^set_custom_gtk_theme() {/,/^}/p' "$ROOT/config/hypr/scripts/DarkLight.sh" > "$tmp/function.sh"
source "$tmp/function.sh"
QT5_CONFIG="$tmp/no-qt5"; QT6_CONFIG="$tmp/no-qt6"
set_custom_gtk_theme Dark
grep -Fxq 'color-scheme|prefer-dark' "$CAPTURE"
grep -q '^gtk-theme|' "$CAPTURE"
grep -q '^icon-theme|' "$CAPTURE"
set_custom_gtk_theme Light
grep -Fxq 'color-scheme|prefer-light' "$CAPTURE"

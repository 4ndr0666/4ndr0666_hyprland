#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WALLUST="$ROOT/config/wallust/wallust.toml"
GHOSTTY_TEMPLATE="$ROOT/config/wallust/templates/colors-ghostty.conf"
GHOSTTY_CONFIG="$ROOT/config/ghostty/ghostty.config"
THEME_CHANGER="$ROOT/config/hypr/scripts/ThemeChanger.sh"

[[ -f "$WALLUST" ]] || { printf '[FAIL] Wallust configuration is missing.\n' >&2; exit 1; }
[[ -f "$GHOSTTY_TEMPLATE" ]] || { printf '[FAIL] Ghostty Wallust template is missing.\n' >&2; exit 1; }
[[ -f "$GHOSTTY_CONFIG" ]] || { printf '[FAIL] Ghostty configuration is missing.\n' >&2; exit 1; }
[[ -f "$THEME_CHANGER" ]] || { printf '[FAIL] Theme changer is missing.\n' >&2; exit 1; }

grep -Fq "ghostty.template = 'colors-ghostty.conf'" "$WALLUST"
grep -Fq "ghostty.target = '~/.config/ghostty/wallust.conf'" "$WALLUST"
! grep -Fq "#ghostty.template = 'colors-ghostty.conf'" "$WALLUST"
! grep -Fq "#ghostty.target = '~/.config/ghostty/wallust.conf'" "$WALLUST"

grep -Fq 'config-file = ?~/.config/ghostty/wallust.conf' "$GHOSTTY_CONFIG"
grep -Fq '"$HOME/.config/ghostty/wallust.conf"' "$THEME_CHANGER"

grep -Fq 'foreground = {{foreground}}' "$GHOSTTY_TEMPLATE"
grep -Fq 'palette = 15={{color15}}' "$GHOSTTY_TEMPLATE"

printf '%s\n' 'Wallust/Ghostty provider-consumer alignment boundary: PASS'

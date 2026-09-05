#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

[[ -f "$ROOT/config/hypr/hypridle.conf" ]]
[[ -f "$ROOT/config/hypr/scripts/TouchPad.sh" ]]
[[ -f "$ROOT/config/hypr/wallust/wallust-hyprland.conf" ]]
[[ ! -e "$ROOT/config/hypr/wallust/wallust-hyprland.lua" ]]

for file in "$ROOT/config/hypr/scripts/TouchPad.sh"; do
  grep -q '^#!/usr/bin/env bash$' "$file"
  grep -q '^set -Eeuo pipefail$' "$file"
done

# Wallust Hyprland output is a configuration file, not a second language-specific duplicate.
! grep -R -n --exclude-dir=.git --exclude-dir=archive 'wallust-hyprland\.lua' "$ROOT" >/dev/null 2>&1

# Preserve established Waybar consumer paths; reject only the obsolete generated-template bypass.
! grep -R -n --exclude-dir=.git --exclude-dir=archive 'wallust/templates/colors-waybar.css' "$ROOT/config/waybar" >/dev/null 2>&1

grep -q 'quickshell' "$ROOT/config/hypr/wallust/wallust-hyprland.conf"
grep -q 'WallustAwww.sh' "$ROOT/config/hypr/scripts/initial-boot.sh" 2>/dev/null || grep -q 'WallustAwww.sh' "$ROOT/config/hypr/initial-boot.sh"

printf '[PASS] current-tree integrity boundary: PASS\n'

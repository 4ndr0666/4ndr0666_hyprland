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
! grep -R -n --exclude-dir=.git --exclude-dir=archive --exclude='test-current-tree-integrity.sh' 'wallust-hyprland\.lua' "$ROOT" >/dev/null 2>&1

# Preserve established Waybar consumer paths; reject only active obsolete template imports.
if grep -R -n --include='*.css' --exclude-dir=.git --exclude-dir=archive -E '^[[:space:]]*@import.*wallust/templates/colors-waybar\.css' "$ROOT/config/waybar" >/dev/null 2>&1; then
  printf '[FAIL] active Waybar import bypasses canonical Wallust consumer.\n' >&2
  exit 1
fi

grep -Eq '^\$background[[:space:]]*=[[:space:]]*rgb\(' "$ROOT/config/hypr/wallust/wallust-hyprland.conf"
grep -Eq '^\$color15[[:space:]]*=[[:space:]]*rgb\(' "$ROOT/config/hypr/wallust/wallust-hyprland.conf"
grep -Fq 'WallustAwww.sh' "$ROOT/config/hypr/initial-boot.sh"

printf '[PASS] current-tree integrity boundary: PASS\n'

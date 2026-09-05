#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

require_file() {
  [[ -f "$1" ]] || { printf '[FAIL] missing required file: %s\n' "$1" >&2; exit 1; }
}

require_file "$ROOT/config/hypr/hypridle.conf"
require_file "$ROOT/config/hypr/scripts/TouchPad.sh"
require_file "$ROOT/config/hypr/wallust/wallust-hyprland.conf"
[[ ! -e "$ROOT/config/hypr/wallust/wallust-hyprland.lua" ]] || { printf '[FAIL] duplicate Wallust Hyprland Lua template remains.\n' >&2; exit 1; }

grep -Fq '#!/usr/bin/env bash' "$ROOT/config/hypr/scripts/TouchPad.sh"
grep -Fq 'set -Eeuo pipefail' "$ROOT/config/hypr/scripts/TouchPad.sh"

! grep -R -n --exclude-dir=.git --exclude-dir=archive --exclude='test-current-tree-integrity.sh' 'wallust-hyprland\.lua' "$ROOT" >/dev/null 2>&1

if grep -R -n --include='*.css' --exclude-dir=.git --exclude-dir=archive -E '^[[:space:]]*@import.*wallust/templates/colors-waybar\.css' "$ROOT/config/waybar" >/dev/null 2>&1; then
  printf '[FAIL] active Waybar import bypasses canonical Wallust consumer.\n' >&2
  exit 1
fi

grep -Fq '$background = rgb(' "$ROOT/config/hypr/wallust/wallust-hyprland.conf"
grep -Fq '$color15 = rgb(' "$ROOT/config/hypr/wallust/wallust-hyprland.conf"
grep -Fq 'WallustAwww.sh' "$ROOT/config/hypr/initial-boot.sh"

printf '[PASS] current-tree integrity boundary: PASS\n'

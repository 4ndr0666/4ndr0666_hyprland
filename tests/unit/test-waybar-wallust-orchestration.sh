#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WALLUST_SCRIPT="$ROOT/config/hypr/scripts/WallustAwww.sh"
INITIAL_BOOT="$ROOT/config/hypr/initial-boot.sh"
RANDOM_WALLPAPER="$ROOT/config/hypr/UserScripts/WallpaperRandom.sh"
AUTO_CHANGE="$ROOT/config/hypr/UserScripts/WallpaperAutoChange.sh"
REFRESH_NO_WAYBAR="$ROOT/config/hypr/scripts/RefreshNoWaybar.sh"
DARK_LIGHT="$ROOT/config/hypr/scripts/DarkLight.sh"

for file in "$WALLUST_SCRIPT" "$INITIAL_BOOT" "$RANDOM_WALLPAPER" "$AUTO_CHANGE" "$REFRESH_NO_WAYBAR" "$DARK_LIGHT"; do
    [[ -f "$file" ]] || {
        printf '%s\n' "Missing Wallust orchestration file: $file" >&2
        exit 1
    }
done

assert_contains() {
    local pattern="$1"
    local file="$2"
    local label="$3"
    if ! grep -Eq "$pattern" "$file"; then
        printf '%s\n' "[ERROR] Missing invariant: $label" >&2
        exit 1
    fi
}

assert_absent() {
    local pattern="$1"
    local file="$2"
    local label="$3"
    if grep -Eq "$pattern" "$file"; then
        printf '%s\n' "[ERROR] Forbidden invariant present: $label" >&2
        exit 1
    fi
}

# WallustAwww.sh is the sole palette-generation boundary.
assert_absent 'wallust run -s' "$INITIAL_BOOT" 'direct Wallust generation in initial boot'
assert_absent 'wallust run -s' "$RANDOM_WALLPAPER" 'direct Wallust generation in random wallpaper'
assert_absent 'wallust run -s' "$AUTO_CHANGE" 'direct Wallust generation in automatic wallpaper'
assert_absent 'WallustSwww\.sh' "$REFRESH_NO_WAYBAR" 'obsolete Swww generator in non-Waybar refresh'
assert_absent 'WallustSwww\.sh' "$DARK_LIGHT" 'obsolete Swww generator in theme switcher'

assert_contains 'WallustAwww\.sh.*wallpaper' "$INITIAL_BOOT" 'initial boot canonical Wallust call'
assert_contains 'WallustAwww\.sh.*RANDOMPICS' "$RANDOM_WALLPAPER" 'random wallpaper canonical Wallust call'
assert_contains 'WallustAwww\.sh.*img' "$AUTO_CHANGE" 'automatic wallpaper canonical Wallust call'
assert_contains 'WallustAwww\.sh.*next_wallpaper' "$DARK_LIGHT" 'DarkLight canonical Wallust call'

# Random wallpaper selection must preserve paths containing whitespace.
assert_contains 'mapfile -d' "$RANDOM_WALLPAPER" 'NUL-safe wallpaper collection'
assert_contains '\$\{AWWW_PARAMS\[@\]\}' "$RANDOM_WALLPAPER" 'array-based transition arguments'

# The non-Waybar refresh must not regenerate or reload the Wallust palette.
assert_absent 'WallustAwww\.sh' "$REFRESH_NO_WAYBAR" 'Wallust generation in non-Waybar refresh'

# Generated consumer reload remains fail-closed at the canonical boundary.
assert_contains 'if ! wallust run -s "\$wallpaper_path"; then' "$WALLUST_SCRIPT" 'fail-closed Wallust generation'
assert_contains '\[ERROR\] Wallust failed; consumers will not be reloaded\.' "$WALLUST_SCRIPT" 'Wallust failure diagnostic'
assert_contains 'validate_target "\$waybar_colors"' "$WALLUST_SCRIPT" 'Waybar target validation'
assert_contains 'waybar-msg cmd reload' "$WALLUST_SCRIPT" 'Waybar consumer reload'

printf '%s\n' 'Waybar/Wallust orchestration boundary: PASS'

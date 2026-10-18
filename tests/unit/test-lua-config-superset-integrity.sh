#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HYPR_LUA="$ROOT/config/hypr/hyprland.lua"
QUICK_SETTINGS="$ROOT/config/hypr/scripts/4ndr0666_Quick_Settings.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

# 1. Verify all authoritative and user-override Lua modules exist and are loaded by hyprland.lua
required_modules=(
  "UserConfigs.01-UserDefaults:config/hypr/UserConfigs/01-UserDefaults.lua"
  "configs.Keybinds:config/hypr/configs/Keybinds.lua"
  "configs.Startup_Apps:config/hypr/configs/Startup_Apps.lua"
  "UserConfigs.Startup_Apps:config/hypr/UserConfigs/Startup_Apps.lua"
  "configs.ENVariables:config/hypr/configs/ENVariables.lua"
  "UserConfigs.ENVariables:config/hypr/UserConfigs/ENVariables.lua"
  "configs.WindowRules:config/hypr/configs/WindowRules.lua"
  "UserConfigs.WindowRules:config/hypr/UserConfigs/WindowRules.lua"
  "configs.SystemSettings:config/hypr/configs/SystemSettings.lua"
  "UserConfigs.UserDecorations:config/hypr/UserConfigs/UserDecorations.lua"
  "UserConfigs.UserAnimations:config/hypr/UserConfigs/UserAnimations.lua"
  "UserConfigs.UserKeybinds:config/hypr/UserConfigs/UserKeybinds.lua"
  "UserConfigs.UserSettings:config/hypr/UserConfigs/UserSettings.lua"
  "UserConfigs.Laptops:config/hypr/UserConfigs/Laptops.lua"
  "monitors:config/hypr/monitors.lua"
  "workspaces:config/hypr/workspaces.lua"
  "UserConfigs.WorkSpaceRules:config/hypr/UserConfigs/WorkSpaceRules.lua"
)

for entry in "${required_modules[@]}"; do
  mod="${entry%%:*}"
  rel="${entry#*:}"
  [[ -s "$ROOT/$rel" ]] || fail "Required Lua module is missing or empty: $rel"
  grep -Fq "source(\"$mod\")" "$HYPR_LUA" || fail "hyprland.lua does not load required module: $mod"
done

# 2. Verify no Lua file under config/hypr contains shell/conf '#' comments
while IFS= read -r -d '' lua_file; do
  if awk 'NR > 1 && /^[[:space:]]*#/ { exit 0 } NR == 1 && /^[[:space:]]*#/ && !/^#!/ { exit 0 } END { exit 1 }' "$lua_file"; then
    fail "Invalid '#' comment syntax in Lua module: $lua_file"
  fi
done < <(find "$ROOT/config/hypr" -type f -name '*.lua' -print0)

# 3. Verify Quick Settings menu targets resolve to existing Lua modules
for target in 01-UserDefaults.lua ENVariables.lua UserKeybinds.lua Startup_Apps.lua WindowRules.lua UserSettings.lua UserDecorations.lua UserAnimations.lua Laptops.lua WorkSpaceRules.lua; do
  grep -Fq "\$UserConfigs/$target" "$QUICK_SETTINGS" || fail "Quick Settings menu is missing UserConfigs target: $target"
  [[ -f "$ROOT/config/hypr/UserConfigs/$target" ]] || fail "Quick Settings target file does not exist: config/hypr/UserConfigs/$target"
done

# 4. Verify runtime helper targets exist and no script calls undefined modify_startup_config or stale mako paths
[[ -x "$ROOT/config/hypr/scripts/KeybindsLayoutInit.sh" ]] || fail "KeybindsLayoutInit.sh is missing or not executable"
[[ -x "$ROOT/config/hypr/UserScripts/RainbowBorders.bak.sh" ]] || fail "RainbowBorders.bak.sh is missing or not executable"
! grep -Fq 'modify_startup_config' "$ROOT/config/hypr/UserScripts/WallpaperSelect.sh" || fail "WallpaperSelect.sh still invokes undefined modify_startup_config"
if grep -RIn '/\.config/mako' "$ROOT/config/hypr/scripts" "$ROOT/config/hypr/UserScripts" >/dev/null 2>&1; then
  fail "Stale ~/.config/mako path remains in Hyprland runtime scripts"
fi

# 5. Verify legacy .conf -> Lua overlay translation works end-to-end
source "$ROOT/scripts/lib_lua_config.sh"
source "$ROOT/scripts/lib_resolution.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/gup-lua-superset.XXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/backup" "$tmp/UserConfigs"
cp "$ROOT/config/hypr/UserConfigs/Startup_Apps.lua" "$tmp/UserConfigs/Startup_Apps.lua"
cp "$ROOT/config/hypr/UserConfigs/ENVariables.lua" "$tmp/UserConfigs/ENVariables.lua"
printf '%s\n' 'exec-once = custom-user-daemon --flag' >"$tmp/backup/Startup_Apps.conf"
printf '%s\n' 'env = CUSTOM_USER_VAR,enabled' >"$tmp/backup/ENVariables.conf"

translate_legacy_userconfigs_to_lua "$tmp/backup" "$tmp/UserConfigs" "$tmp/migration.log"
translate_legacy_userconfigs_to_lua "$tmp/backup" "$tmp/UserConfigs" "$tmp/migration.log"
[[ "$(grep -Fc 'hl.exec_cmd("custom-user-daemon --flag")' "$tmp/UserConfigs/Startup_Apps.lua")" -eq 1 ]] ||
  fail "Legacy Startup_Apps.conf exec-once was not idempotently translated to Lua"
[[ "$(grep -Fc 'hl.env("CUSTOM_USER_VAR", "enabled")' "$tmp/UserConfigs/ENVariables.lua")" -eq 1 ]] ||
  fail "Legacy ENVariables.conf env was not idempotently translated to Lua"

printf '%s\n' '[PASS] Lua configuration superset, module graph, Quick Settings targets, and legacy migration contracts verified.'

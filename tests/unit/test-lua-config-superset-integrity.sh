#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

# 1. Verify every module required by config/hypr/hyprland.lua exists and is non-empty
HYPR_MAIN="$ROOT/config/hypr/hyprland.lua"
[[ -f "$HYPR_MAIN" ]] || fail "Missing $HYPR_MAIN"

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

if command -v luac >/dev/null 2>&1; then
  LUA_COMPILER=luac
elif command -v luac5.4 >/dev/null 2>&1; then
  LUA_COMPILER=luac5.4
elif command -v texluac >/dev/null 2>&1; then
  LUA_COMPILER=texluac
else
  fail "No Lua parser installed; install lua5.4 (CI contract is fail-closed)"
fi
"$LUA_COMPILER" -v

for entry in "${required_modules[@]}"; do
  mod="${entry%%:*}"
  rel="${entry#*:}"
  path="$ROOT/$rel"
  grep -Fq "source(\"$mod\")" "$HYPR_MAIN" || fail "hyprland.lua does not require $mod"
  [[ -s "$path" ]] || fail "Required Lua module is missing or 0-byte: $rel"
  if grep -Eq '^[[:space:]]*#' "$path"; then
    fail "Lua module $rel contains invalid shell '#' comment syntax"
  fi
  "$LUA_COMPILER" -p "$path" || fail "Lua syntax error in $rel (parser: $LUA_COMPILER)"
done

# 2. Verify universal monitors.lua and workspaces.lua have zero hardcoded personal hardware descriptors (Ruling #3)
! grep -Fq 'desc:' "$ROOT/config/hypr/monitors.lua" || fail "monitors.lua contains hardcoded hardware desc: selector"
! grep -Fq 'desc:' "$ROOT/config/hypr/workspaces.lua" || fail "workspaces.lua contains hardcoded hardware desc: selector"
grep -Fq 'output = ""' "$ROOT/config/hypr/monitors.lua" || fail "monitors.lua missing universal fallback output = \"\""

# 3. Verify strictly-Lua hyprctl IPC compliance across config/hypr, config/waybar, config/swaync, config/wlogout (Ruling #4)
if grep -RIhE 'hyprctl[[:space:]]+keyword|windowrulev2|movetoworkspacesilent|Hyprland\.dispatch\([`"](workspace|movetoworkspacesilent|focuswindow|closewindow|exec)[[:space:]]|hyprctl[[:space:]]+dispatch[[:space:]]+(layoutmsg|splitratio|workspaceopt|setprop|exit|dpms|workspace[[:space:]])' \
  "$ROOT/config/hypr" "$ROOT/config/waybar" "$ROOT/config/swaync" "$ROOT/config/wlogout" "$ROOT/config/quickshell" 2>/dev/null | grep -vE '^[[:space:]]*(#|--|//)' >/dev/null 2>&1; then
  fail "Legacy non-Lua hyprctl keyword or hyprlang dispatcher found in active configuration/scripts"
fi

if grep -RInE 'getoption[[:space:]]+[a-z_]+:' "$ROOT/config/hypr/scripts" "$ROOT/config/hypr/UserScripts" >/dev/null 2>&1; then
  fail "Legacy colon-delimited hyprctl getoption found in Hyprland scripts"
fi

# 4. Verify 4ndr0666_Quick_Settings.sh targets existing Lua files
QS="$ROOT/config/hypr/scripts/4ndr0666_Quick_Settings.sh"
[[ -x "$QS" ]] || fail "Quick Settings script is not executable"
! grep -Fq 'Settings.conf' "$QS" || fail "Quick Settings still references legacy Settings.conf"
for target in 01-UserDefaults.lua ENVariables.lua UserKeybinds.lua Startup_Apps.lua WindowRules.lua UserSettings.lua UserDecorations.lua UserAnimations.lua Laptops.lua WorkSpaceRules.lua; do
  grep -Fq "$target" "$QS" || fail "Quick Settings does not expose $target"
done

# 5. Verify runtime helper targets exist and retired redundant paths are absent (Ruling #5)
[[ -x "$ROOT/config/hypr/scripts/KeybindsLayoutInit.sh" ]] || fail "Missing executable KeybindsLayoutInit.sh"
[[ -x "$ROOT/config/hypr/UserScripts/RainbowBorders.bak.sh" ]] || fail "Missing executable RainbowBorders.bak.sh"
! grep -Fq 'modify_startup_config' "$ROOT/config/hypr/UserScripts/WallpaperSelect.sh" || fail "Undefined modify_startup_config call remains in WallpaperSelect.sh"
if grep -RIn '/\.config/mako' "$ROOT/config/hypr/scripts" "$ROOT/config/hypr/UserScripts" >/dev/null 2>&1; then
  fail "Stale ~/.config/mako path remains in Hyprland runtime scripts"
fi
for retired in \
  config/waybar/WaybarWorkspaces \
  config/ghostty/config.ghostty \
  config/hypr/UserScripts/alacritty4ndr066 \
  config/hypr/UserScripts/startup \
  config/hypr/UserScripts/startup4ndr0666 \
  config/hypr/UserScripts/mako; do
  [[ ! -e "$ROOT/$retired" ]] || fail "Authorized-retired path still exists in worktree: $retired"
done

# 6. Verify Rofi rasi files have no unclosed quotes or typos and Wallust template defines required color aliases
! grep -Fq 'colums:' "$ROOT/config/rofi/config-rofi-Beats-menu.rasi" || fail "Typo 'colums:' remains in config-rofi-Beats-menu.rasi"
grep -Fq 'placeholder: " Choose Media or Stations to play";' "$ROOT/config/rofi/config-rofi-Beats.rasi" || fail "Unclosed quote in config-rofi-Beats.rasi not fixed"
for alias_key in background-alt selected active urgent; do
  grep -Fq "${alias_key}:" "$ROOT/config/wallust/templates/colors-rofi.rasi" || fail "Missing ${alias_key} in wallust template colors-rofi.rasi"
  grep -Fq "${alias_key}:" "$ROOT/config/rofi/wallust/colors-rofi.rasi" || fail "Missing ${alias_key} in rofi/wallust/colors-rofi.rasi"
done

# 7. Verify legacy .conf to Lua translation helper is complete, valid Lua, and idempotent
# shellcheck source=/dev/null
source "$ROOT/scripts/lib_resolution.sh"
# shellcheck source=/dev/null
source "$ROOT/scripts/lib_lua_config.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gup-lua-superset.XXXXXX")"
trap 'rm -rf -- "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/backup" "$TMP_DIR/UserConfigs" "$TMP_DIR/hypr_backup" "$TMP_DIR/hypr_target"
for f in 01-UserDefaults.lua Startup_Apps.lua ENVariables.lua WindowRules.lua UserKeybinds.lua UserSettings.lua WorkSpaceRules.lua; do
  cp "$ROOT/config/hypr/UserConfigs/$f" "$TMP_DIR/UserConfigs/$f"
done
cp "$ROOT/config/hypr/monitors.lua" "$TMP_DIR/hypr_target/monitors.lua"
cp "$ROOT/config/hypr/workspaces.lua" "$TMP_DIR/hypr_target/workspaces.lua"

cat >"$TMP_DIR/backup/01-UserDefaults.conf" <<'EOF'
env = EDITOR,vim
$term = alacritty
EOF

cat >"$TMP_DIR/backup/Startup_Apps.conf" <<'EOF'
exec-once = custom-user-daemon --flag
exec-once = $scriptsDir/KeybindsLayoutInit.sh
# exec-once = disabled-user-daemon
EOF

cat >"$TMP_DIR/backup/ENVariables.conf" <<'EOF'
env = CUSTOM_USER_VAR,custom_val
EOF

cat >"$TMP_DIR/backup/WindowRules.conf" <<'EOF'
windowrule = float, class:^(my-custom-app)$
windowrulev2 = opacity 0.92 0.84, class:^(my-custom-app)$, title:^(Custom)$
layerrule = blur, custom-overlay
# windowrule = float, class:^(disabled-app)$
EOF

cat >"$TMP_DIR/backup/UserKeybinds.conf" <<'EOF'
bind = $mainMod, U, exec, custom-keybind-cmd
binde = $mainMod SHIFT, U, workspace, 4
EOF

cat >"$TMP_DIR/backup/UserSettings.conf" <<'EOF'
kb_layout = us,de
EOF

cat >"$TMP_DIR/backup/WorkSpaceRules.conf" <<'EOF'
workspace = 3, monitor:DP-2
EOF

cat >"$TMP_DIR/hypr_backup/monitors.conf" <<'EOF'
monitor = DP-2, 2560x1440@144, 0x0, 1.0
EOF

cat >"$TMP_DIR/hypr_backup/workspaces.conf" <<'EOF'
workspace = 1, monitor:DP-2
EOF

translate_legacy_userconfigs_to_lua "$TMP_DIR/backup" "$TMP_DIR/UserConfigs" "/dev/null"
translate_legacy_monitors_and_workspaces_to_lua "$TMP_DIR/hypr_backup" "$TMP_DIR/hypr_target" "/dev/null"

grep -Fq 'hl.env("EDITOR", "vim")' "$TMP_DIR/UserConfigs/01-UserDefaults.lua" || fail "Legacy 01-UserDefaults.conf EDITOR was not translated"
grep -Fq 'local term = "alacritty"' "$TMP_DIR/UserConfigs/01-UserDefaults.lua" || fail "Legacy 01-UserDefaults.conf term was not translated"
grep -Fq 'hl.exec_cmd("custom-user-daemon --flag")' "$TMP_DIR/UserConfigs/Startup_Apps.lua" || fail "Legacy Startup_Apps.conf command was not translated"
grep -Fq -- '-- disabled-by-user: exec-once = disabled-user-daemon' "$TMP_DIR/UserConfigs/Startup_Apps.lua" || fail "Disabled Startup_Apps.conf entry was not preserved"
! grep -Fq 'KeybindsLayoutInit.sh' "$TMP_DIR/UserConfigs/Startup_Apps.lua" || fail "Canonical startup command was duplicated into UserConfigs/Startup_Apps.lua"
grep -Fq 'hl.env("CUSTOM_USER_VAR", "custom_val")' "$TMP_DIR/UserConfigs/ENVariables.lua" || fail "Legacy ENVariables.conf variable was not translated"
grep -Fq 'hl.window_rule({ match = { class = "^(my-custom-app)$" }, float = true })' "$TMP_DIR/UserConfigs/WindowRules.lua" || fail "Legacy windowrule was not translated"
grep -Fq 'hl.window_rule({ match = { class = "^(my-custom-app)$", title = "^(Custom)$" }, opacity = "0.92 0.84" })' "$TMP_DIR/UserConfigs/WindowRules.lua" || fail "Legacy windowrulev2 was not translated"
grep -Fq 'hl.layer_rule({ match = { namespace = "custom-overlay" }, blur = true })' "$TMP_DIR/UserConfigs/WindowRules.lua" || fail "Legacy layerrule was not translated"
grep -Fq 'hl.bind("SUPER + U", hl.dsp.exec_cmd("custom-keybind-cmd")' "$TMP_DIR/UserConfigs/UserKeybinds.lua" || fail "Legacy bind was not translated"
grep -Fq 'kb_layout = "us,de"' "$TMP_DIR/UserConfigs/UserSettings.lua" || fail "Legacy UserSettings.conf kb_layout was not translated"
grep -Fq 'hl.workspace_rule({ workspace = 3, monitor = "DP-2" })' "$TMP_DIR/UserConfigs/WorkSpaceRules.lua" || fail "Legacy WorkSpaceRules.conf was not translated"
grep -Fq 'hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1.0 })' "$TMP_DIR/hypr_target/monitors.lua" || fail "Legacy monitors.conf was not translated"
grep -Fq 'hl.workspace_rule({ workspace = 1, monitor = "DP-2" })' "$TMP_DIR/hypr_target/workspaces.lua" || fail "Legacy workspaces.conf was not translated"

for mutated_lua in \
  "$TMP_DIR/UserConfigs/Startup_Apps.lua" \
  "$TMP_DIR/UserConfigs/ENVariables.lua" \
  "$TMP_DIR/UserConfigs/WindowRules.lua" \
  "$TMP_DIR/UserConfigs/UserKeybinds.lua" \
  "$TMP_DIR/UserConfigs/UserSettings.lua" \
  "$TMP_DIR/UserConfigs/WorkSpaceRules.lua" \
  "$TMP_DIR/hypr_target/monitors.lua" \
  "$TMP_DIR/hypr_target/workspaces.lua"; do
  [[ "$(tail -n 1 "$mutated_lua")" == "return true" ]] || fail "Mutated Lua module $mutated_lua does not end with 'return true'"
  if command -v luac >/dev/null 2>&1; then
    luac -p "$mutated_lua" || fail "Lua syntax error in mutated $mutated_lua"
  elif command -v texluac >/dev/null 2>&1; then
    texluac -p "$mutated_lua" || fail "Lua syntax error in mutated $mutated_lua"
  fi
done

before_sha="$(sha256sum "$TMP_DIR"/UserConfigs/*.lua "$TMP_DIR"/hypr_target/*.lua)"
translate_legacy_userconfigs_to_lua "$TMP_DIR/backup" "$TMP_DIR/UserConfigs" "/dev/null"
translate_legacy_monitors_and_workspaces_to_lua "$TMP_DIR/hypr_backup" "$TMP_DIR/hypr_target" "/dev/null"
after_sha="$(sha256sum "$TMP_DIR"/UserConfigs/*.lua "$TMP_DIR"/hypr_target/*.lua)"
[[ "$before_sha" == "$after_sha" ]] || fail "legacy .conf to Lua translation is not idempotent"

printf '[PASS] Lua configuration superset, strictly-Lua IPC, universal monitor defaults, and authorized retirements verified (parser: %s).\n' "$LUA_COMPILER"

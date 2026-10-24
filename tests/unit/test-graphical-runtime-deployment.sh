#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY="$ROOT/install-scripts/graphical-runtime.sh"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf -- "$TMP_HOME"' EXIT

mkdir -p "$TMP_HOME/.config/hypr/configs"
cat > "$TMP_HOME/.config/hypr/hyprland.lua" <<'LUA'
local home = os.getenv("HOME")
local function source(module_name)
    return require(module_name)
end
source("UserConfigs.01-UserDefaults")
source("configs.Keybinds")
source("configs.SystemSettings")
LUA
cat > "$TMP_HOME/.config/hypr/configs/Startup_Apps.lua" <<'LUA'
-- user startup customizations must be preserved
hl.on("hyprland.start", function ()
    hl.exec_cmd("custom-user-command")
end)
return true
LUA

HOME="$TMP_HOME" XDG_STATE_HOME="$TMP_HOME/.local/state" bash "$DEPLOY"

ENTRYPOINT="$TMP_HOME/.config/hypr/hyprland.lua"
STARTUP="$TMP_HOME/.config/hypr/configs/Startup_Apps.lua"
INITIALIZER="$TMP_HOME/.config/hypr/UserScripts/4ndr0init.sh"

[[ -x "$INITIALIZER" ]]
grep -Fq 'custom-user-command' "$STARTUP"
grep -Fq 'hl.exec_cmd(UserScripts .. "/4ndr0init.sh")' "$STARTUP"
grep -Fq 'source("configs.Startup_Apps")' "$ENTRYPOINT"
grep -Fq 'source("configs.SystemSettings")' "$ENTRYPOINT"

# Deployment is idempotent: a second run does not duplicate the loader or hook.
HOME="$TMP_HOME" XDG_STATE_HOME="$TMP_HOME/.local/state" bash "$DEPLOY"
[[ "$(grep -Fc 'source("configs.Startup_Apps")' "$ENTRYPOINT")" -eq 1 ]]
[[ "$(grep -Fc 'hl.exec_cmd(UserScripts .. "/4ndr0init.sh")' "$STARTUP")" -eq 1 ]]

printf '%s\n' 'PASS: mandatory graphical runtime deployment preserves user startup entries and is idempotent'

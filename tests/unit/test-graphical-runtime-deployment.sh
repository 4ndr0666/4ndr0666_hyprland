#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY="$ROOT/install-scripts/graphical-runtime.sh"
grep -Fq "run_module graphical-runtime.sh" "$ROOT/install.sh"
TMP_HOME="$(mktemp -d)"
MISSING_HOME="$(mktemp -d)"
AUTOGEN_HOME="$(mktemp -d)"
trap 'rm -rf -- "$TMP_HOME" "$MISSING_HOME" "$AUTOGEN_HOME"' EXIT

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
[[ -x "$TMP_HOME/.config/hypr/UserScripts/NetworkBackend.py" ]]
cmp "$ROOT/config/hypr/UserScripts/NetworkBackend.py" "$TMP_HOME/.config/hypr/UserScripts/NetworkBackend.py"
grep -Fq 'custom-user-command' "$STARTUP"
grep -Fq 'hl.exec_cmd(UserScripts .. "/4ndr0init.sh")' "$STARTUP"
grep -Fq 'source("configs.Startup_Apps")' "$ENTRYPOINT"
grep -Fq 'source("configs.SystemSettings")' "$ENTRYPOINT"

# Deployment is idempotent: a second run does not duplicate the loader or hook.
HOME="$TMP_HOME" XDG_STATE_HOME="$TMP_HOME/.local/state" bash "$DEPLOY"
[[ "$(grep -Fc 'source("configs.Startup_Apps")' "$ENTRYPOINT")" -eq 1 ]]
[[ "$(grep -Fc 'hl.exec_cmd(UserScripts .. "/4ndr0init.sh")' "$STARTUP")" -eq 1 ]]

# A customized initializer is user-owned and must stop deployment before any
# startup, entrypoint, or helper is changed.
CUSTOM_HOME="$(mktemp -d)"
mkdir -p "$CUSTOM_HOME/.config/hypr/UserScripts" "$CUSTOM_HOME/.config/hypr/configs"
printf '%s\n' 'custom entrypoint' > "$CUSTOM_HOME/.config/hypr/hyprland.lua"
printf '%s\n' '#!/bin/sh' 'echo custom' > "$CUSTOM_HOME/.config/hypr/UserScripts/4ndr0init.sh"
chmod +x "$CUSTOM_HOME/.config/hypr/UserScripts/4ndr0init.sh"
BEFORE="$(sha256sum "$CUSTOM_HOME/.config/hypr/UserScripts/4ndr0init.sh")"
if HOME="$CUSTOM_HOME" XDG_STATE_HOME="$CUSTOM_HOME/.local/state" bash "$DEPLOY"; then
  printf '%s\n' 'FAIL: customized initializer was accepted' >&2
  exit 1
fi
[[ "$BEFORE" == "$(sha256sum "$CUSTOM_HOME/.config/hypr/UserScripts/4ndr0init.sh")" ]]
[[ ! -e "$CUSTOM_HOME/.config/hypr/UserScripts/NetworkBackend.py" ]]
[[ ! -e "$CUSTOM_HOME/.config/hypr/configs/Startup_Apps.lua" ]]
rm -rf -- "$CUSTOM_HOME"

# The independently captured initializer differs only in comments and is retained.
CAPTURE_HOME="$(mktemp -d)"
mkdir -p "$CAPTURE_HOME/.config/hypr/UserScripts"
printf '%s\n' 'local function source(module_name)' 'return require(module_name)' 'end' 'source("configs.Keybinds")' > "$CAPTURE_HOME/.config/hypr/hyprland.lua"
awk '{print} /^set -euo pipefail$/ {print "# This is the synchronous initialization for D-Bus, Environment, Portals "; print "# and graphical runtime daemons."; print "# "}' "$ROOT/config/hypr/UserScripts/4ndr0init.sh" > "$CAPTURE_HOME/.config/hypr/UserScripts/4ndr0init.sh"
chmod +x "$CAPTURE_HOME/.config/hypr/UserScripts/4ndr0init.sh"
BEFORE="$(sha256sum "$CAPTURE_HOME/.config/hypr/UserScripts/4ndr0init.sh")"
[[ "${BEFORE%% *}" == 4720b7baa7140a606fa0e3ca7262c7d76afec5002afbfded408d1d003cd078f3 ]]
HOME="$CAPTURE_HOME" XDG_STATE_HOME="$CAPTURE_HOME/.local/state" bash "$DEPLOY"
[[ "$BEFORE" == "$(sha256sum "$CAPTURE_HOME/.config/hypr/UserScripts/4ndr0init.sh")" ]]
# A conflicting user network helper must block before modifying any file.
printf '%s\n' '#!/bin/sh' 'echo custom' > "$CAPTURE_HOME/.config/hypr/UserScripts/NetworkBackend.py"
chmod +x "$CAPTURE_HOME/.config/hypr/UserScripts/NetworkBackend.py"
BEFORE="$(sha256sum "$CAPTURE_HOME/.config/hypr/UserScripts/NetworkBackend.py")"
if HOME="$CAPTURE_HOME" XDG_STATE_HOME="$CAPTURE_HOME/.local/state" bash "$DEPLOY"; then exit 1; fi
[[ "$BEFORE" == "$(sha256sum "$CAPTURE_HOME/.config/hypr/UserScripts/NetworkBackend.py")" ]]
rm -rf -- "$CAPTURE_HOME"

# The captured desktop startup is upgraded with a recorded backup.
DESKTOP_HOME="$(mktemp -d)"
mkdir -p "$DESKTOP_HOME/.config/hypr/configs"
printf '%s\n' 'local function source(module_name)' 'return require(module_name)' 'end' 'source("configs.Keybinds")' > "$DESKTOP_HOME/.config/hypr/hyprland.lua"
git -C "$ROOT" show 8dbe1e8219c45a4bd00c26425e4867da901e88eb:config/hypr/configs/Startup_Apps.lua | awk '/hl.exec_cmd\(UserScripts .. "\/4ndr0init.sh"\)/ {print "    hl.exec_cmd(\"awww-daemon --format xrgb\")"} {print}' > "$DESKTOP_HOME/.config/hypr/configs/Startup_Apps.lua"
[[ $(sha256sum "$DESKTOP_HOME/.config/hypr/configs/Startup_Apps.lua" | cut -d' ' -f1) == 30e72ee267f1c43ee7f416434205777488e73b75a1890eb1f093c264e091c958 ]]
cp "$ROOT/tests/fixtures/desktop-migration/initial-boot.sh" "$DESKTOP_HOME/.config/hypr/initial-boot.sh"
HOME="$DESKTOP_HOME" XDG_STATE_HOME="$DESKTOP_HOME/.local/state" bash "$DEPLOY"
cmp "$ROOT/config/hypr/initial-boot.sh" "$DESKTOP_HOME/.config/hypr/initial-boot.sh"
cmp "$ROOT/config/hypr/configs/Startup_Apps.lua" "$DESKTOP_HOME/.config/hypr/configs/Startup_Apps.lua"
grep -Fq 'replaced' "$DESKTOP_HOME/.local/state/4ndr0666-hyprland/files.manifest"
rm -rf -- "$DESKTOP_HOME"

# A clean profile without Startup_Apps.lua receives the repository module.
mkdir -p "$MISSING_HOME/.config/hypr"
cat > "$MISSING_HOME/.config/hypr/hyprland.lua" <<'LUA'
local function source(module_name)
    return require(module_name)
end
source("UserConfigs.01-UserDefaults")
source("configs.Keybinds")
LUA
HOME="$MISSING_HOME" XDG_STATE_HOME="$MISSING_HOME/.local/state" bash "$DEPLOY"
[[ -x "$MISSING_HOME/.config/hypr/UserScripts/4ndr0init.sh" ]]
grep -Fq 'hl.on("hyprland.start"' "$MISSING_HOME/.config/hypr/configs/Startup_Apps.lua"
grep -Fq 'hl.exec_cmd(UserScripts .. "/4ndr0init.sh")' "$MISSING_HOME/.config/hypr/configs/Startup_Apps.lua"
grep -Fq 'source("configs.Startup_Apps")' "$MISSING_HOME/.config/hypr/hyprland.lua"

# Autogenerated direct hl.* Lua configs have no source(module_name) helper.
# Preserve settings and add one absolute-path dofile connection.
mkdir -p "$AUTOGEN_HOME/.config/hypr"
cat > "$AUTOGEN_HOME/.config/hypr/hyprland.lua" <<'LUA'
hl.config({ autogenerated = true })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
hl.env("XCURSOR_SIZE", "24")
LUA
HOME="$AUTOGEN_HOME" XDG_STATE_HOME="$AUTOGEN_HOME/.local/state" bash "$DEPLOY"
AUTO_ENTRYPOINT="$AUTOGEN_HOME/.config/hypr/hyprland.lua"
AUTO_LOADER='dofile(os.getenv("HOME") .. "/.config/hypr/configs/Startup_Apps.lua")'
grep -Fq 'hl.config({ autogenerated = true })' "$AUTO_ENTRYPOINT"
grep -Fq 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })' "$AUTO_ENTRYPOINT"
grep -Fq 'hl.env("XCURSOR_SIZE", "24")' "$AUTO_ENTRYPOINT"
grep -Fq "$AUTO_LOADER" "$AUTO_ENTRYPOINT"
[[ "$(grep -Fc "$AUTO_LOADER" "$AUTO_ENTRYPOINT")" -eq 1 ]]
HOME="$AUTOGEN_HOME" XDG_STATE_HOME="$AUTOGEN_HOME/.local/state" bash "$DEPLOY"
[[ "$(grep -Fc "$AUTO_LOADER" "$AUTO_ENTRYPOINT")" -eq 1 ]]

printf '%s\\n' 'PASS: mandatory graphical runtime deployment preserves user startup entries, supports autogenerated hl.* Lua configs, initializes clean profiles, and is idempotent'

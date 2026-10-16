#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COPY="$ROOT/copy.sh"
LUA_HELPERS="$ROOT/scripts/lib_lua_config.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/gup-core-contracts.XXXXXX")"
cleanup() { rm -rf -- "$TMP_ROOT"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

for script in \
  "$ROOT/Distro-Hyprland.sh" \
  "$ROOT/install.sh" \
  "$ROOT/uninstall.sh" \
  "$COPY" \
  "$ROOT"/scripts/*.sh \
  "$ROOT"/install-scripts/*.sh \
  "$ROOT"/install-scripts/core/*.sh; do
  [[ -f "$script" ]] || continue
  bash -n "$script" || fail "shell syntax failed: $script"
done

[[ -f "$LUA_HELPERS" ]] || fail "shared Lua mutation helper is missing"
for helper in copy_menu.sh lib_backup.sh lib_lua_config.sh lib_detect.sh lib_prompts.sh lib_apps.sh lib_copy.sh lib_resolution.sh lib_waybar.sh; do
  [[ -f "$ROOT/scripts/$helper" ]] || fail "missing copy helper: $helper"
  grep -Fq "source \"\$SOURCE_ROOT/scripts/$helper\"" "$COPY" ||
    fail "copy.sh does not source required helper: $helper"
done
grep -Fq 'source "$SOURCE_ROOT/scripts/lib_lua_config.sh"' "$COPY" ||
  fail "copy.sh does not source the shared Lua mutation helper"
grep -Fq 'command -v xdg-user-dirs-update' "$COPY" ||
  fail "copy.sh does not guard the optional xdg-user-dirs-update command"
grep -Fq 'set_lua_assignment "$file" "kb_layout"' "$ROOT/scripts/lib_prompts.sh" ||
  fail "keyboard prompt is not connected to the shared Lua settings mutation"
grep -Fq 'config/hypr/UserConfigs/01-UserDefaults.lua' "$ROOT/scripts/lib_apps.sh" ||
  fail "editor selection does not target the authoritative Lua defaults module"

if grep -Eq '(Startup_Apps|ENVariables|SystemSettings|monitors|01-UserDefaults)\.conf' \
  "$ROOT/scripts/lib_apps.sh" "$ROOT/scripts/lib_detect.sh" "$ROOT/scripts/lib_prompts.sh"; then
  fail "active copy helpers still reference legacy Hyprland .conf modules"
fi

mkdir -p "$TMP_ROOT/config/hypr/configs"
cat >"$TMP_ROOT/config/hypr/configs/Startup_Apps.lua" <<'LUA'
hl.on("hyprland.start", function()
    hl.exec_cmd("base-command")
end)
LUA
cat >"$TMP_ROOT/config/hypr/configs/ENVariables.lua" <<'LUA'
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
LUA
cat >"$TMP_ROOT/config/hypr/configs/SystemSettings.lua" <<'LUA'
hl.config({
    input = {
        kb_layout = "us",
    },
    cursor = {
        no_hardware_cursors = 2,
    },
})
LUA
cat >"$TMP_ROOT/config/hypr/monitors.lua" <<'LUA'
hl.monitor({ output = "test-monitor", mode = "1920x1080@60.0" })
LUA

cd "$TMP_ROOT"
# shellcheck disable=SC1090
source "$LUA_HELPERS"

append_startup_command "qs"
append_startup_command "qs"
[[ "$(grep -Fc 'hl.exec_cmd("qs")' config/hypr/configs/Startup_Apps.lua)" -eq 1 ]] ||
  fail "startup command append is not idempotent"

# A grep I/O error is not equivalent to an expected no-match result.
before="$(sha256sum config/hypr/configs/Startup_Apps.lua)"
if (
  grep() { return 2; }
  append_lua_module_line \
    "config/hypr/configs/Startup_Apps.lua" \
    "never-present-marker" \
    'hl.exec_cmd("must-not-be-appended")'
); then
  fail "Lua append accepted a marker-inspection I/O error"
else
  status=$?
  [[ "$status" -eq 2 ]] || fail "Lua append normalized grep I/O error to status $status"
fi
after="$(sha256sum config/hypr/configs/Startup_Apps.lua)"
[[ "$before" == "$after" ]] || fail "failed marker inspection mutated the Lua target"

append_startup_expression "KeybindsLayoutInit.sh" 'os.getenv("HOME") .. "/.config/hypr/scripts/KeybindsLayoutInit.sh"'
append_startup_expression "KeybindsLayoutInit.sh" 'os.getenv("HOME") .. "/.config/hypr/scripts/KeybindsLayoutInit.sh"'
[[ "$(grep -Fc 'KeybindsLayoutInit.sh' config/hypr/configs/Startup_Apps.lua)" -eq 1 ]] ||
  fail "startup expression append is not idempotent"

append_lua_env "WLR_RENDERER_ALLOW_SOFTWARE" "1"
append_lua_env "WLR_RENDERER_ALLOW_SOFTWARE" "1"
[[ "$(grep -Fc 'hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")' config/hypr/configs/ENVariables.lua)" -eq 1 ]] ||
  fail "Lua environment append is not idempotent"

set_lua_assignment "config/hypr/configs/SystemSettings.lua" "kb_layout" '"us,kr"'
set_lua_assignment "config/hypr/configs/SystemSettings.lua" "no_hardware_cursors" "1"
grep -Fq 'kb_layout = "us,kr",' config/hypr/configs/SystemSettings.lua ||
  fail "keyboard layout mutation did not preserve Lua syntax"
grep -Fq 'no_hardware_cursors = 1,' config/hypr/configs/SystemSettings.lua ||
  fail "cursor mutation did not update the Lua setting"

before="$(sha256sum config/hypr/configs/SystemSettings.lua)"
if set_lua_assignment "config/hypr/configs/SystemSettings.lua" "kb_layout" '"; os.execute("false") --'; then
  fail "unsafe Lua value was accepted"
fi
after="$(sha256sum config/hypr/configs/SystemSettings.lua)"
[[ "$before" == "$after" ]] || fail "rejected Lua mutation changed the target file"

append_lua_module_line \
  "config/hypr/monitors.lua" \
  'output = "Virtual-1"' \
  $'hl.monitor({\n    output = "Virtual-1",\n    mode = "1920x1080@60.0",\n    position = "0x0",\n    scale = 1.0\n})'
append_lua_module_line \
  "config/hypr/monitors.lua" \
  'output = "Virtual-1"' \
  $'hl.monitor({\n    output = "Virtual-1",\n    mode = "1920x1080@60.0",\n    position = "0x0",\n    scale = 1.0\n})'
[[ "$(grep -Fc 'output = "Virtual-1"' config/hypr/monitors.lua)" -eq 1 ]] ||
  fail "monitor Lua append is not idempotent"
if find "$TMP_ROOT/config" -type f -name '.*.lua.*' -print -quit | grep -q .; then
  fail "Lua mutation left temporary files behind"
fi

printf '[PASS] core shell syntax, Lua paths, atomic edits, and idempotent mutations are validated.\n'

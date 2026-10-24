#!/usr/bin/env bash
# Deploy mandatory graphical runtime infrastructure independently of optional styling.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_ROOT="$ROOT/config/hypr"
HYPR_HOME="$HOME/.config/hypr"
ENTRYPOINT="$HYPR_HOME/hyprland.lua"
STARTUP="$HYPR_HOME/configs/Startup_Apps.lua"
INITIALIZER="$HYPR_HOME/UserScripts/4ndr0init.sh"

fail() {
  printf '[ERROR] Graphical runtime deployment: %s\n' "$*" >&2
  exit 1
}

for source in \
  "$CONFIG_ROOT/UserScripts/4ndr0init.sh" \
  "$CONFIG_ROOT/configs/Startup_Apps.lua"; do
  [[ -f "$source" && -r "$source" ]] || fail "required repository source is missing or unreadable: $source"
done
[[ -f "$ENTRYPOINT" && -r "$ENTRYPOINT" ]] || fail "Hyprland Lua entrypoint is missing or unreadable: $ENTRYPOINT. Deploy a compatible Hyprland configuration before installing mandatory runtime hooks."

source "$SCRIPT_DIR/core/files.sh"

mkdir -p "$HYPR_HOME/configs" "$HYPR_HOME/UserScripts"

# Replace only the owned initializer when its contents differ. Existing
# versions are backed up through the canonical file-state manifest.
if [[ -L "$INITIALIZER" ]] || ! cmp -s -- "$CONFIG_ROOT/UserScripts/4ndr0init.sh" "$INITIALIZER" 2>/dev/null; then
  file_state_atomic_replace "$CONFIG_ROOT/UserScripts/4ndr0init.sh" "$INITIALIZER"
fi
chmod +x -- "$INITIALIZER"

# Preserve user startup additions. Copy the repository default only when no
# Startup_Apps module exists; otherwise inject just the mandatory initializer
# hook if it is absent.
if [[ ! -f "$STARTUP" ]]; then
  file_state_atomic_replace "$CONFIG_ROOT/configs/Startup_Apps.lua" "$STARTUP"
fi

if ! grep -Fq 'hl.exec_cmd(UserScripts .. "/4ndr0init.sh")' "$STARTUP"; then
  startup_tmp="$(mktemp --tmpdir="$(dirname "$STARTUP")" ".Startup_Apps.lua.XXXXXX")"
  hook_tmp="$(mktemp)"
  cleanup_startup_temps() {
    rm -f -- "$startup_tmp" "$hook_tmp"
  }
  trap cleanup_startup_temps EXIT
  cat > "$hook_tmp" <<'LUA'
hl.on("hyprland.start", function ()
    local UserScripts = os.getenv("HOME") .. "/.config/hypr/UserScripts"
    hl.exec_cmd(UserScripts .. "/4ndr0init.sh")
end)
LUA
  awk -v hookfile="$hook_tmp" '
    /^[[:space:]]*return[[:space:]]+true[[:space:]]*$/ && !inserted {
      while ((getline line < hookfile) > 0) print line
      close(hookfile)
      print ""
      inserted=1
    }
    { print }
    END {
      if (!inserted) {
        while ((getline line < hookfile) > 0) print line
        close(hookfile)
      }
    }
  ' "$STARTUP" > "$startup_tmp" || fail "could not prepare Startup_Apps.lua initializer hook"
  chmod --reference="$STARTUP" "$startup_tmp" || fail "could not preserve Startup_Apps.lua permissions"
  file_state_atomic_replace "$startup_tmp" "$STARTUP"
  rm -f -- "$startup_tmp" "$hook_tmp"
  trap - EXIT
fi

# The existing entrypoint must use the repository's Lua module loader. Add
# only the missing module connection and preserve all unrelated user settings.
if ! grep -Fq 'source("configs.Startup_Apps")' "$ENTRYPOINT"; then
  grep -Eq '^[[:space:]]*local function source\(module_name\)' "$ENTRYPOINT" ||
    fail "entrypoint does not expose the expected Lua source(module_name) loader: $ENTRYPOINT"
  anchor='source("configs.Keybinds")'
  grep -Fq "$anchor" "$ENTRYPOINT" ||
    anchor='source("UserConfigs.01-UserDefaults")'
  grep -Fq "$anchor" "$ENTRYPOINT" ||
    fail "entrypoint has no safe insertion point for the mandatory Startup_Apps loader: $ENTRYPOINT"

  entry_tmp="$(mktemp --tmpdir="$(dirname "$ENTRYPOINT")" ".hyprland.lua.XXXXXX")"
  awk -v anchor="$anchor" '
    !inserted && index($0, anchor) { print "source(\"configs.Startup_Apps\")"; inserted=1 }
    { print }
    END { if (!inserted) exit 42 }
  ' "$ENTRYPOINT" > "$entry_tmp" || {
    rm -f -- "$entry_tmp"
    fail "could not prepare the mandatory Startup_Apps loader"
  }
  chmod --reference="$ENTRYPOINT" "$entry_tmp" || {
    rm -f -- "$entry_tmp"
    fail "could not preserve Hyprland entrypoint permissions"
  }
  file_state_atomic_replace "$entry_tmp" "$ENTRYPOINT"
  rm -f -- "$entry_tmp"
fi

grep -Fq 'hl.on("hyprland.start"' "$STARTUP" ||
  fail "Startup_Apps.lua does not register the Hyprland start hook after deployment"
grep -Fq 'hl.exec_cmd(UserScripts .. "/4ndr0init.sh")' "$STARTUP" ||
  fail "Startup_Apps.lua does not contain the mandatory initializer command after deployment"
grep -Fq 'source("configs.Startup_Apps")' "$ENTRYPOINT" ||
  fail "Hyprland entrypoint does not load Startup_Apps after deployment"
[[ -x "$INITIALIZER" ]] || fail "deployed initializer is not executable"

printf '%s\n' '[PASS] Mandatory graphical runtime files and startup connection are deployed.'

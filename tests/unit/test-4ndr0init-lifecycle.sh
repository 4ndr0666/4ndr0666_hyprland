#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/config/hypr/UserScripts/4ndr0init.sh"
STARTUP="$ROOT_DIR/config/hypr/configs/Startup_Apps.lua"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -f "$SCRIPT" ]] || fail "4ndr0init.sh is missing"
[[ -f "$STARTUP" ]] || fail "Startup_Apps.lua is missing"

grep -Fq 'set -euo pipefail' "$SCRIPT" || fail "initialization must fail closed"
grep -Fq ': "${DBUS_SESSION_BUS_ADDRESS:?D-Bus session bus address is unavailable}"' "$SCRIPT" || fail "D-Bus readiness assertion is missing"
grep -Fq 'dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP' "$SCRIPT" || fail "Wayland environment publication is missing"
grep -Fq 'systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP' "$SCRIPT" || fail "systemd user environment import is missing"

grep -Fq 'start_portal_binary "xdg-desktop-portal-hyprland"' "$SCRIPT" || fail "Hyprland portal startup boundary is missing"
grep -Fq 'start_portal_binary "xdg-desktop-portal"' "$SCRIPT" || fail "generic portal startup boundary is missing"
grep -Fq 'return 1' "$SCRIPT" || fail "portal discovery failure is not loud"
grep -Fq 'started_portal_pids=()' "$SCRIPT" || fail "portal startup ownership state is missing"
grep -Fq 'cleanup_started_portals()' "$SCRIPT" || fail "portal rollback boundary is missing"
grep -Fq 'trap on_exit EXIT' "$SCRIPT" || fail "startup rollback is not unconditional"
grep -Fq 'started_portal_pids+=("$pid")' "$SCRIPT" || fail "started portal process is not tracked"
grep -Fq 'kill "$pid"' "$SCRIPT" || fail "rollback does not terminate started portal processes"
grep -Fq 'portal startup rollback failed' "$SCRIPT" || fail "rollback failure is not surfaced"
grep -Fq 'exited during startup with status' "$SCRIPT" || fail "portal process failure is not surfaced"
grep -Fq 'status=$?' "$SCRIPT" || fail "portal failure status is not captured explicitly"
grep -Fq 'exit "$status"' "$SCRIPT" || fail "original startup failure status is not propagated"
grep -Fq 'return "$cleanup_failed"' "$SCRIPT" || fail "cleanup failures are not propagated"
grep -Fq '130|137|143' "$SCRIPT" || fail "expected termination statuses are not scoped"

if grep -Fq 'METHOD 2' "$SCRIPT" || grep -Fq 'pidof "${_prs}"' "$SCRIPT"; then
    fail "retired duplicate portal implementation remains"
fi

grep -Fq 'hl.exec_cmd(UserScripts .. "/4ndr0init.sh")' "$STARTUP" || fail "Hyprland startup no longer invokes 4ndr0init.sh"
grep -Fq 'hl.on("hyprland.start"' "$STARTUP" || fail "4ndr0init.sh is not bound to Hyprland startup"

printf 'PASS: 4ndr0init owns D-Bus, environment, and portal startup with fail-closed transactional lifecycle semantics\n'

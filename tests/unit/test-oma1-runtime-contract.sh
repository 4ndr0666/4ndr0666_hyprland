#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HARNESS="$ROOT/tests/oma/run-oma1.sh"

[[ -r "$HARNESS" ]] || { printf '[FAIL] O.M.A.-1 baseline harness is unavailable.\n' >&2; exit 1; }

assert_contains() {
  local needle="$1"
  grep -F -- "$needle" "$HARNESS" >/dev/null || {
    printf '[FAIL] O.M.A.-1 harness is missing required contract: %s\n' "$needle" >&2
    exit 1
  }
}

assert_absent() {
  local needle="$1"
  if grep -F -- "$needle" "$HARNESS" >/dev/null; then
    printf '[FAIL] O.M.A.-1 harness contains forbidden contract: %s\n' "$needle" >&2
    exit 1
  fi
}

assert_contains 'mode=oma1-baseline'
assert_contains 'WAYLAND_DISPLAY'
assert_contains 'XDG_CURRENT_DESKTOP'
assert_contains 'systemctl --user is-system-running'
assert_contains 'systemctl --user --failed --no-legend --no-pager'
assert_contains 'case "$state" in'
assert_contains 'degraded)'
assert_contains 'busctl --user list'
assert_contains 'hyprctl monitors'
assert_contains 'pactl info'
assert_contains 'awww query'
assert_contains 'pidof waybar'
assert_contains 'summary_failures='
assert_contains 'sha256sum "$EVIDENCE" > "$EVIDENCE.sha256"'
assert_contains 'if HYPRLAND_PID="$('
assert_contains 'HYPRLAND_PID='
assert_contains 'hyprctl instances'
assert_contains 'wl socket:'
assert_contains 'wayland_display_source=hyprctl_instances'
assert_contains 'Hyprland process WAYLAND_DISPLAY does not match Hyprland instance wl socket:'
assert_contains 'hyprland_process=FAIL'
assert_contains 'Active Hyprland compositor process was not found for the current user.'
assert_contains 'fatal_error='
assert_absent 'HYPRLAND_PID="$(pgrep'
assert_absent 'reboot'
assert_absent 'pacman -S'
assert_absent 'systemctl enable'
assert_absent 'systemctl start'
assert_absent 'rm -rf'

printf '%s\n' 'O.M.A.-1 runtime baseline contract: PASS'

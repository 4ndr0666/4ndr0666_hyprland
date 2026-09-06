#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/config/hypr/scripts/PortalHyprland.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -f "$SCRIPT" ]] || fail "PortalHyprland.sh is missing"
grep -Fq 'kill_quietly xdg-desktop-portal-hyprland' "$SCRIPT" || fail "Hyprland portal cleanup boundary is missing"
grep -Fq 'kill_quietly xdg-desktop-portal-wlr' "$SCRIPT" || fail "WLR portal cleanup boundary is missing"
grep -Fq 'kill_quietly xdg-desktop-portal-gnome' "$SCRIPT" || fail "GNOME portal cleanup boundary is missing"
grep -Fq 'kill_quietly xdg-desktop-portal' "$SCRIPT" || fail "generic portal cleanup boundary is missing"
grep -Fq '/usr/lib/xdg-desktop-portal-hyprland' "$SCRIPT" || fail "Hyprland portal candidate is missing"
grep -Fq '/usr/libexec/xdg-desktop-portal-hyprland' "$SCRIPT" || fail "Hyprland portal exec candidate is missing"
grep -Fq '/usr/lib/xdg-desktop-portal' "$SCRIPT" || fail "generic portal candidate is missing"
grep -Fq '/usr/libexec/xdg-desktop-portal' "$SCRIPT" || fail "generic portal exec candidate is missing"
grep -Fq 'return 1' "$SCRIPT" || fail "portal startup failure is not loud"

grep -Fq 'killall -q "$1" 2>/dev/null || true' "$SCRIPT" || fail "bounded portal cleanup normalization changed unexpectedly"

printf 'PASS: portal lifecycle cleanup, candidate resolution, and loud startup failure are bounded\n'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$ROOT/config/swaync/config.json"
STYLE="$ROOT/config/swaync/style.css"
REFRESH="$ROOT/config/hypr/scripts/Refresh.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

[[ -f "$CONFIG" ]] || fail "SwayNC configuration is missing"
[[ -f "$STYLE" ]] || fail "SwayNC style is missing"
[[ -f "$REFRESH" ]] || fail "refresh integration is missing"

grep -Fq '"control-center-layer": "top"' "$CONFIG" || fail "SwayNC control center is not configured as a session consumer"
grep -Fq '@import' "$STYLE" || fail "SwayNC style is not connected to its theme source"
grep -Eq 'swaync( |$)|swaync-client' "$REFRESH" || fail "refresh path has no SwayNC runtime edge"

grep -Rqs 'SWAYNC_BYPASS_DND' "$ROOT/config/hypr/scripts" || fail "notification-producing runtime path has no SwayNC observable contract"

printf 'PASS: SwayNC configuration, styling, refresh, and notification paths are connected\n'

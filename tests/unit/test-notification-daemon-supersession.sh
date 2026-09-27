#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
startup="$ROOT/config/hypr/configs/Startup_Apps.lua"
init="$ROOT/config/hypr/UserScripts/4ndr0init.sh"

if grep -Eq 'hl\.exec_cmd\(["'"']mako(["'"']|[[:space:]])' "$startup"; then
  printf '[FAIL] canonical Hyprland startup still launches legacy mako.\n' >&2
  exit 1
fi

if grep -Eq '^[[:space:]]*kill_quietly[[:space:]]+mako([[:space:]]|$)' "$init"; then
  printf '[FAIL] canonical initialization still manages legacy mako.\n' >&2
  exit 1
fi

if ! grep -q 'swaync' "$ROOT/config/swaync/config.json"; then
  printf '[FAIL] canonical SwayNC configuration is missing.\n' >&2
  exit 1
fi

printf '%s\n' 'notification-daemon supersession boundary: PASS'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/hypr/scripts/KeyboardLayout.sh"

[[ -f "$SCRIPT" ]] || { printf '%s\n' 'missing KeyboardLayout.sh' >&2; exit 1; }
grep -Eq '^set -Eeuo pipefail$' "$SCRIPT" || { printf '%s\n' 'KeyboardLayout.sh lacks strict shell lifecycle semantics' >&2; exit 1; }
grep -Eq 'devices_json=.*hyprctl devices -j' "$SCRIPT" || { printf '%s\n' 'keyboard device state is not captured once' >&2; exit 1; }
if grep -Eq '\$1' "$SCRIPT"; then
  printf '%s\n' 'KeyboardLayout.sh reads a missing positional argument directly' >&2
  exit 1
fi
grep -Eq 'case "\$\{1-\}" in' "$SCRIPT" || { printf '%s\n' 'keyboard command dispatch is not total' >&2; exit 1; }
grep -Eq 'Usage: .*\{status\|switch\}' "$SCRIPT" || { printf '%s\n' 'invalid keyboard command does not fail with usage' >&2; exit 1; }
grep -Eq 'if hyprctl switchxkblayout' "$SCRIPT" || { printf '%s\n' 'keyboard layout mutation does not propagate authoritative failure' >&2; exit 1; }
grep -Eq 'layout_index < \$\{#layout_mapping\[@\]\}' "$SCRIPT" || { printf '%s\n' 'active layout index is not bounds checked' >&2; exit 1; }
grep -Eq 'next_index < \$\{#variant_mapping\[@\]\}' "$SCRIPT" || { printf '%s\n' 'variant array length is not guarded' >&2; exit 1; }

printf '%s\n' 'Keyboard layout lifecycle boundary: PASS'

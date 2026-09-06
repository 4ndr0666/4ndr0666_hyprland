#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COPY="$ROOT/copy.sh"

[[ -f "$COPY" ]] || { printf '[FAIL] Missing copy.sh\n' >&2; exit 1; }
bash -n "$COPY"
grep -Fq 'cd -- "$SCRIPT_DIR"' "$COPY"

cd_line="$(grep -n '^cd -- "$SCRIPT_DIR"$' "$COPY" | head -n1 | cut -d: -f1)"
phase1_line="$(grep -n '^copy_phase1 ' "$COPY" | head -n1 | cut -d: -f1)"
waybar_line="$(grep -n '^copy_waybar ' "$COPY" | head -n1 | cut -d: -f1)"
phase2_line="$(grep -n '^copy_phase2 ' "$COPY" | head -n1 | cut -d: -f1)"
[[ -n "$cd_line" && -n "$phase1_line" && -n "$waybar_line" && -n "$phase2_line" ]]
(( cd_line < phase1_line ))
(( cd_line < waybar_line ))
(( cd_line < phase2_line ))

printf '[PASS] copy workflow establishes repository cwd before all relative-source phases.\n'

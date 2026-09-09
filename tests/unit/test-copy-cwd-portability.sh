#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COPY="$ROOT/copy.sh"

[[ -f "$COPY" ]] || { printf '[FAIL] Missing copy.sh\n' >&2; exit 1; }
bash -n "$COPY"
grep -Fq 'cd -- "$DEPLOY_STAGE_DIR"' "$COPY"
grep -Fq 'SCRIPT_DIR="$DEPLOY_STAGE_DIR"' "$COPY"

gcd_line="$(grep -n '^cd -- "$DEPLOY_STAGE_DIR"$' "$COPY" | head -n1 | cut -d: -f1)"
phase1_line="$(grep -n '^copy_phase1 ' "$COPY" | head -n1 | cut -d: -f1)"
waybar_line="$(grep -n '^copy_waybar ' "$COPY" | head -n1 | cut -d: -f1)"
phase2_line="$(grep -n '^copy_phase2 ' "$COPY" | head -n1 | cut -d: -f1)"
[[ -n "$gcd_line" && -n "$phase1_line" && -n "$waybar_line" && -n "$phase2_line" ]]
(( gcd_line < phase1_line ))
(( gcd_line < waybar_line ))
(( gcd_line < phase2_line ))

printf '[PASS] copy workflow establishes ephemeral staged cwd before all relative-source phases.\n'

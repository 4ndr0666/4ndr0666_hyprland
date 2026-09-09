#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COPY="$ROOT/copy.sh"
RESOLUTION="$ROOT/scripts/lib_resolution.sh"

[[ -f "$COPY" ]] || { printf '[FAIL] Missing copy.sh\n' >&2; exit 1; }
[[ -f "$RESOLUTION" ]] || { printf '[FAIL] Missing resolution helper.\n' >&2; exit 1; }
bash -n "$COPY"
bash -n "$RESOLUTION"

# Resolution customization must operate on installed destinations and remain
# isolated from repository-owned config files before and during deployment.
grep -Fq 'source "$SOURCE_ROOT/scripts/lib_resolution.sh"' "$COPY"
! grep -Fq 'apply_resolution_profile() {' "$COPY"
! grep -Fq 'SCRIPT_DIR/config/' "$RESOLUTION"
grep -Fq '"$HOME/.config/kitty/kitty.conf"' "$RESOLUTION"
grep -Fq '"$HOME/.config/hypr/hyprlock.conf"' "$RESOLUTION"
grep -Fq '"$HOME/.config/rofi/0-shared-fonts.rasi"' "$RESOLUTION"
grep -Fq 'transaction_dir=' "$RESOLUTION"
grep -Fq 'Resolution-profile transaction failed; prior state restored.' "$RESOLUTION"

grep -Fq 'copy_phase2 "$LOG"' "$COPY"
apply_line="$(grep -n '^apply_resolution_profile ' "$COPY" | head -n1 | cut -d: -f1)"
copy_line="$(grep -n '^copy_phase2 ' "$COPY" | head -n1 | cut -d: -f1)"
[[ "$apply_line" -gt "$copy_line" ]] || {
  printf '[FAIL] Resolution profile is applied before destination copy completes.\n' >&2
  exit 1
}

printf '[PASS] resolution customization is destination-scoped and transaction-bounded.\n'

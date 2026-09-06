#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COPY="$ROOT/copy.sh"

[[ -f "$COPY" ]] || { printf '[FAIL] Missing copy.sh\n' >&2; exit 1; }
bash -n "$COPY"

# Resolution customization must operate on the installed destination, never
# mutate repository-owned config files before the copy transaction.
start="$(grep -n '^apply_resolution_profile() {' "$COPY" | cut -d: -f1)"
end="$(awk 'NR > 1 && /^}$/ { if (seen) { print NR; exit } } /^apply_resolution_profile\(\) \{/ { seen=1 }' "$COPY")"
[[ -n "$start" && -n "$end" ]] || { printf '[FAIL] Could not isolate apply_resolution_profile.\n' >&2; exit 1; }

function_body="$(sed -n "${start},${end}p" "$COPY")"

! grep -Fq 'SCRIPT_DIR/config/' <<<"$function_body"
! grep -Fq '"$SCRIPT_DIR/' <<<"$function_body"
grep -Fq '"$HOME/.config/kitty/kitty.conf"' <<<"$function_body"
grep -Fq '"$HOME/.config/hypr/hyprlock.conf"' <<<"$function_body"
grep -Fq '"$HOME/.config/rofi/0-shared-fonts.rasi"' <<<"$function_body"

grep -Fq 'copy_phase2 "$LOG"' "$COPY"
apply_line="$(grep -n '^apply_resolution_profile ' "$COPY" | head -n1 | cut -d: -f1)"
copy_line="$(grep -n '^copy_phase2 ' "$COPY" | head -n1 | cut -d: -f1)"
[[ "$apply_line" -gt "$copy_line" ]] || {
  printf '[FAIL] Resolution profile is applied before destination copy completes.\n' >&2
  exit 1
}

printf '[PASS] resolution customization is destination-scoped and runs after copy transaction.\n'

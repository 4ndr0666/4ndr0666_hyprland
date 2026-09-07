#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/hypr/scripts/ThemeChanger.sh"

[[ -f "$SCRIPT" ]] || { printf '%s\n' 'missing ThemeChanger.sh' >&2; exit 1; }
grep -Eq '^set -Eeuo pipefail$' "$SCRIPT" || { printf '%s\n' 'ThemeChanger.sh lacks strict shell semantics' >&2; exit 1; }
grep -Eq '^trap cleanup EXIT$' "$SCRIPT" || { printf '%s\n' 'ThemeChanger temporary state lacks unconditional cleanup' >&2; exit 1; }
grep -Eq 'if choice=.*wallust theme list' "$SCRIPT" || { printf '%s\n' 'theme selection does not isolate expected Rofi cancellation status' >&2; exit 1; }
grep -Eq 'case "\$prompt_status" in' "$SCRIPT" || { printf '%s\n' 'theme selection status is not explicitly classified' >&2; exit 1; }
grep -Fq 'Theme selection failed with status' "$SCRIPT" || { printf '%s\n' 'unexpected theme selection failure is not surfaced' >&2; exit 1; }
grep -Fq 'Theme transaction incomplete' "$SCRIPT" || { printf '%s\n' 'generated theme targets are not fail-closed' >&2; exit 1; }
grep -Eq 'rofi_tmp=.*mktemp' "$SCRIPT" || { printf '%s\n' 'Rofi palette normalization is not staged atomically' >&2; exit 1; }
grep -Fq 'mv -f -- "$rofi_tmp" "$rofi_colors"' "$SCRIPT" || { printf '%s\n' 'Rofi palette normalization is not atomically committed' >&2; exit 1; }
if grep -Eq '|| true' "$SCRIPT"; then
  printf '%s\n' 'ThemeChanger contains generic failure swallowing' >&2
  exit 1
fi
if grep -Eq '^set \+e$' "$SCRIPT"; then
  printf '%s\n' 'ThemeChanger disables strict error handling' >&2
  exit 1
fi

printf '%s\n' 'ThemeChanger lifecycle boundary: PASS'

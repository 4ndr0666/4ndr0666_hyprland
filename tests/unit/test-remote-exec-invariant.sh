#!/usr/bin/env bash
# Golden Unit: mutable remote content must never be executed directly.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGETS=(
  "$ROOT/install.sh"
  "$ROOT/Distro-Hyprland.sh"
  "$ROOT/install-scripts"
)

for target in "${TARGETS[@]}"; do
  if grep -R -nE --exclude-dir=.git '(curl|wget)[[:space:]].*\|[[:space:]]*(sh|bash|zsh)|source[[:space:]]+<\([[:space:]]*(curl|wget)' "$target"; then
    printf '[FAIL] Mutable remote content is executed directly: %s\n' "$target" >&2
    exit 1
  fi
done

printf '[PASS] Installer paths contain no direct curl/wget-to-shell execution.\n'

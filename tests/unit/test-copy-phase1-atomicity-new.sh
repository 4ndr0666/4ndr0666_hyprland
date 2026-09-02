#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
COPY_SCRIPT="$ROOT_DIR/assets/hyprland-install/copy.sh"

if ! grep -Eq 'replace_dir_transaction[[:space:]]+"\$src"[[:space:]]+"\$dst"' "$COPY_SCRIPT"; then
  echo "copy_phase1 is not using replace_dir_transaction" >&2
  exit 1
fi

if grep -Eq 'rm -rf[[:space:]]+"\$dst"|mv[[:space:]]+"\$dst"|cp -r[[:space:]]+"\$src"[[:space:]]+"\$dst"' "$COPY_SCRIPT"; then
  echo "copy_phase1 contains destructive live-destination mutation" >&2
  exit 1
fi

echo "copy phase1 atomicity: PASS"

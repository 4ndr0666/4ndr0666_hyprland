#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
cd "$ROOT_DIR"

LOG="${LOG:-Install-Logs/install-$(date +%d-%H%M%S)_final-check.log}"
mkdir -p "$(dirname "$LOG")"
source "$SCRIPT_DIR/core/package-manifest.sh"
source "$SCRIPT_DIR/core/packages.sh"

missing=()
for pkg in "${CANONICAL_BASELINE_PACKAGES[@]}" "${CANONICAL_BASELINE_AUR_PACKAGES[@]}"; do
  package_is_installed "$pkg" || missing+=("$pkg")
done

if ((${#missing[@]} == 0)); then
  printf '%s\n' '[OK] Canonical baseline package verification passed.' | tee -a "$LOG"
  exit 0
fi

printf '[ERROR] Missing canonical baseline packages: %s\n' "${missing[*]}" | tee -a "$LOG" >&2
exit 1

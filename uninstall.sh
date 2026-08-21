#!/bin/bash
# === 4ndr0666 === #
# Remove only packages recorded as installer-owned.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$SCRIPT_DIR/install-scripts/core/packages.sh"

if [[ ! -r "$CORE" ]]; then
  printf '%s\n' '[ERROR] Package core is unavailable; refusing destructive uninstall.' >&2
  exit 1
fi

source "$CORE"

LOG="$SCRIPT_DIR/Install-Logs/uninstall-$(date +%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG")"

if [[ ! -s "$PACKAGE_MANIFEST" ]]; then
  printf '%s\n' '[INFO] No installer-owned package manifest exists. Nothing to uninstall.'
  exit 0
fi

printf '%s\n' '[ACTION] Removing packages recorded as installer-owned.'
printf '%s\n' "[INFO] Manifest: $PACKAGE_MANIFEST"

if package_remove_owned; then
  printf '%s\n' '[OK] Installer-owned package removal completed.'
else
  printf '%s\n' '[ERROR] Package removal failed; ownership manifest was retained for retry.' >&2
  exit 1
fi

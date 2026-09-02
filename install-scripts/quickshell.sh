#!/usr/bin/env bash
# === 4ndr0666 === #
# Quickshell installer for the desktop overview.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$ROOT/Install-Logs"
LOG="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S)_quickshell.log"

mkdir -p -- "$LOG_DIR"

# Quickshell is distributed by Arch; keep the installer deliberately thin.
# The package core owns package transactions, logging, timeouts, and manifests.
# Do not source presets or execute repository-controlled shell fragments here.
# shellcheck disable=SC1091
source "$SCRIPT_DIR/core/packages.sh"

printf '[INFO] Installing Quickshell desktop shell dependencies.\n' | tee -a "$LOG"
package_install qt6-5compat quickshell

command -v qs >/dev/null 2>&1 || {
  printf '[ERROR] Quickshell package transaction completed but qs is unavailable.\n' | tee -a "$LOG" >&2
  exit 1
}

if ! package_is_installed quickshell; then
  printf '[ERROR] Quickshell package is not installed after transaction.\n' | tee -a "$LOG" >&2
  exit 1
fi

printf '[OK] Quickshell is installed and the qs launcher is available.\n' | tee -a "$LOG"

#!/usr/bin/env bash
# Configure pacman presentation settings and synchronize package databases.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
cd "$ROOT"

LOG="${LOG:-Install-Logs/install-$(date +%d-%H%M%S)_pacman.log}"
mkdir -p "$(dirname "$LOG")"
export LOG

source "$SCRIPT_DIR/core/packages.sh"

pacman_conf="/etc/pacman.conf"
lines_to_edit=(Color CheckSpace VerbosePkgLists ParallelDownloads)

printf '[INFO] Configuring pacman.conf.\n' | tee -a "$LOG"
for line in "${lines_to_edit[@]}"; do
  if grep -q "^#$line" "$pacman_conf"; then
    sudo sed -i "s/^#$line/$line/" "$pacman_conf"
  fi
done

if grep -q '^ParallelDownloads' "$pacman_conf" && ! grep -q '^ILoveCandy' "$pacman_conf"; then
  sudo sed -i '/^ParallelDownloads/a ILoveCandy' "$pacman_conf"
fi

package_sync

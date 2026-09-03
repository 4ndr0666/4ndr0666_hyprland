#!/usr/bin/env bash
# 4ndr0666
set -Eeuo pipefail

# Quickshell is the sole overview provider.
if qs ipc -c overview call overview toggle >/dev/null 2>&1; then
  exit 0
fi

# Start the canonical overview shell when no IPC endpoint is available.
qs -c overview >/dev/null 2>&1 &
sleep 0.6

if qs ipc -c overview call overview toggle >/dev/null 2>&1; then
  exit 0
fi

printf '%s\n' '[ERROR] Quickshell overview is unavailable.' >&2
notify-send 'Overview' 'Quickshell overview is unavailable' -u low 2>/dev/null || true
exit 1

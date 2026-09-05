#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QUICKSHELL="$ROOT/config/quickshell"

[[ -f "$QUICKSHELL/overview/shell.qml" ]]
grep -Fq 'import "./modules/overview/"' "$QUICKSHELL/overview/shell.qml"

# The active overview implementation lives under config/quickshell/overview.
# A second top-level modules/overview implementation is an unreferenced fork.
[[ ! -d "$QUICKSHELL/modules/overview" ]]
! grep -R -n --exclude-dir=.git --exclude-dir=archive 'config/quickshell/modules/overview' "$ROOT" >/dev/null 2>&1

printf '%s\n' '[PASS] Quickshell overview has one active implementation.'

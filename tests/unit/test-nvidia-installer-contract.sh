#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/install-scripts/nvidia.sh"

fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

bash -n "$SCRIPT" || fail 'NVIDIA installer syntax is invalid'
grep -Fq 'set -Eeuo pipefail' "$SCRIPT" || fail 'NVIDIA installer is not fail-fast'
grep -Fq 'RUN_ID="$(date +%Y%m%dT%H%M%S%N)"' "$SCRIPT" || fail 'NVIDIA state is not isolated per run'
grep -Fq 'STATE_FILE="$STATE_DIR/state-$RUN_ID.manifest"' "$SCRIPT" || fail 'NVIDIA state manifest can overwrite a prior run'
grep -Fq 'BACKUP_DIR="$STATE_DIR/backups/$RUN_ID"' "$SCRIPT" || fail 'NVIDIA backups can overwrite a prior run'
grep -Fq 'cleanup_temporary_files()' "$SCRIPT" || fail 'NVIDIA temporary-file cleanup is missing'
grep -Fq 'trap cleanup_temporary_files EXIT' "$SCRIPT" || fail 'NVIDIA cleanup is not guaranteed on exit'
grep -Fq 'trap - ERR' "$SCRIPT" || fail 'NVIDIA rollback can recursively invoke its ERR trap'
grep -Fq 'sudo cat -- "$entry" | awk' "$SCRIPT" || fail 'privileged entry reads are not separated from user-owned temporary output'
grep -Fq '> "$ENTRY_TMP"' "$SCRIPT" || fail 'systemd-boot mutation does not write to its tracked temporary file'
! grep -Fq '"$tmp"' "$SCRIPT" || fail 'NVIDIA installer contains an unbound temporary variable'

printf '%s\n' 'nvidia-installer-contract: PASS'

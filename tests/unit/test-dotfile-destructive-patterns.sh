#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib_backup.sh"

grep -q '^replace_dir_transaction()' "$ROOT/scripts/lib_backup.sh"
grep -q 'mv -- "\$destination" "\$backup"' "$ROOT/scripts/lib_backup.sh"
grep -q 'mv -- "\$candidate" "\$destination"' "$ROOT/scripts/lib_backup.sh"
grep -q 'mv -- "\$backup" "\$destination"' "$ROOT/scripts/lib_backup.sh"

echo 'dotfile destructive-pattern invariant: PASS'

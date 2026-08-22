#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# copy helpers must not remove a live config before a replacement is prepared.
if grep -RInE 'rm -rf .*\$DIRPATH|rm -rf .*\$DIRPATHw|mv .*\$DIRPATH .*backup' \
  "$ROOT/scripts/lib_copy.sh" "$ROOT/copy.sh" >/dev/null 2>&1; then
  echo 'destructive live-destination mutation detected' >&2
  exit 1
fi

# Transactional replacement must remain the only generic directory replacement primitive.
grep -q '^replace_dir_transaction()' "$ROOT/scripts/lib_backup.sh"

echo 'dotfile destructive-pattern invariant: PASS'

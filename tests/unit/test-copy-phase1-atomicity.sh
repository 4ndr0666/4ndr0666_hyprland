#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# copy_phase1 must use the canonical transactional directory replacement primitive.
if ! grep -q 'replace_dir_transaction "config/$dir_name" "$dir_path" "$log"' "$ROOT/scripts/lib_copy.sh"; then
  echo 'copy_phase1 is not using replace_dir_transaction' >&2
  exit 1
fi

# The phase must not remove or move the live destination before preparation.
if sed -n '/^copy_phase1()/,/^}/p' "$ROOT/scripts/lib_copy.sh" | grep -Eq '^[[:space:]]*(rm -rf|mv) '; then
  echo 'copy_phase1 contains destructive live-destination mutation' >&2
  exit 1
fi

echo 'copy phase1 atomicity invariant: PASS'

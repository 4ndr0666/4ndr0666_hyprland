#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for script in run-oma.sh run-oma1.sh run-oma2.sh; do
  path="$ROOT/tests/oma/$script"
  [[ -x "$path" ]] || {
    printf '[FAIL] O.M.A. runner is not executable: %s\n' "$path" >&2
    exit 1
  }
done

printf '%s\n' 'PASS: O.M.A. runner executable contract'

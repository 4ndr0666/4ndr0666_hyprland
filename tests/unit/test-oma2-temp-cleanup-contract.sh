#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for script in "$ROOT/tests/oma/lib/concurrency.sh" "$ROOT/tests/oma/lib/interruption.sh" "$ROOT/tests/oma/lib/recovery.sh"; do
  bash -n "$script"
  grep -Fq 'trap ' + "'" + 'rm -rf -- "$workdir"' + "'" + ' EXIT' "$script" || {
    printf '[FAIL] O.M.A.-2 temporary cleanup trap missing: %s\n' "$script" >&2
    exit 1
  }
  grep -Fq 'workdir="$(mktemp -d)"' "$script" || {
    printf '[FAIL] O.M.A.-2 temporary workdir missing: %s\n' "$script" >&2
    exit 1
  }
done

printf '%s\n' 'PASS: O.M.A.-2 temporary cleanup contract'

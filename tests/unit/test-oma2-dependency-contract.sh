#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/oma/run-oma2.sh"

bash -n "$RUNNER"
grep -Fq 'for cmd in bash awk cat cp date grep mkdir mktemp mv rm sed sha256sum sleep flock systemctl busctl pidof uname id tr wc; do' "$RUNNER" || {
  printf '%s\n' '[FAIL] O.M.A.-2 direct dependency command contract is incomplete.' >&2
  exit 1
}

printf '%s\n' 'PASS: O.M.A.-2 dependency contract'

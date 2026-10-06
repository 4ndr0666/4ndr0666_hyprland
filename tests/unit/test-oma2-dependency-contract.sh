#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/oma/run-oma2.sh"

bash -n "$RUNNER"

required='bash awk cat cp date grep mkdir mktemp mv rm sed sha256sum sleep flock systemctl busctl pidof uname id tr wc'
for cmd in $required; do
  grep -Eq "for cmd in .*\\b$cmd\\b" "$RUNNER" || {
    printf '[FAIL] O.M.A.-2 dependency missing from prerequisite command contract: %s\n' "$cmd" >&2
    exit 1
  }
done

printf '%s\n' 'PASS: O.M.A.-2 dependency contract'

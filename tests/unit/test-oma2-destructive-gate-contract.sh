#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/oma/run-oma2.sh"

bash -n "$RUNNER"
grep -Fq "destructive_gate=REJECTED" "$RUNNER"
grep -Fq "destructive_reason=OMA2_DESTRUCTIVE=1 is required on a disposable certification host" "$RUNNER"
grep -Fq 'failures=$((failures + 1))' "$RUNNER"

printf '%s\n' 'PASS: O.M.A.-2 destructive gate evidence contract'

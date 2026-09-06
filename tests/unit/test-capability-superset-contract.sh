#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MATRIX="$ROOT/docs/audits/GUP-capability-observable-contract-matrix-2026-09-06.md"
RUNNER="$ROOT/tests/unit/run-golden-units.sh"

[[ -r "$MATRIX" ]] || { printf '%s\n' '[ERROR] Capability contract matrix is unavailable.' >&2; exit 1; }
[[ -r "$RUNNER" ]] || { printf '%s\n' '[ERROR] Golden Unit registry is unavailable.' >&2; exit 1; }

bash -n "$RUNNER"

grep -Fq 'C45 — capability-preserving deployment' "$MATRIX"
grep -Fq 'Supported capabilities at baseline' "$MATRIX"
grep -Fq 'Supported capabilities after deployment/update' "$MATRIX"
grep -Fq 'Intentional retirement decisions' "$MATRIX"
grep -Fq 'authoritative implementation' "$MATRIX"
grep -Fq 'integration edge' "$MATRIX"
grep -Fq 'transaction boundaries' "$MATRIX"
grep -Fq 'externally observable result' "$MATRIX"

grep -Fq 'tests/unit/test-capability-superset-contract.sh' "$RUNNER"
grep -Fq 'tests/unit/test-uninstall-symmetry-contract.sh' "$RUNNER"
grep -Fq 'C44' "$MATRIX"
grep -Fq 'C45' "$MATRIX"

if grep -Eq 'C45[^\n]*(file count|find .*wc|wc -l)' "$MATRIX"; then
  printf '%s\n' '[ERROR] C45 was reduced to a file-count invariant.' >&2
  exit 1
fi

printf '%s\n' '[PASS] C45 capability-preserving deployment is a formal semantic superset contract and is registered.'

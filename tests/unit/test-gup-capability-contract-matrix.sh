#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
MATRIX="$ROOT_DIR/docs/audits/GUP-capability-observable-contract-matrix-2026-09-06.md"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -f "$MATRIX" ]] || fail "capability contract matrix is missing"
grep -Fq 'C45' "$MATRIX" || fail "C45 architectural invariant is missing"
grep -Fq 'C30' "$MATRIX" || fail "C30 keybind invariant is missing"
grep -Fq 'C44' "$MATRIX" || fail "C44 uninstall invariant is missing"
grep -Fq 'C30–C45' "$MATRIX" || fail "bounded validation boundary is missing"
grep -Fq 'D6 / EAFP constraint' "$MATRIX" || fail "D6/EAFP constraint is missing"

printf 'PASS: GUP capability contract matrix invariants are registered\n'

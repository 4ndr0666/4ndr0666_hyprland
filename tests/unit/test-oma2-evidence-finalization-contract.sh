#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/tests/oma/lib/evidence.sh"

bash -n "$LIB"

grep -Fq 'oma2_evidence_finalize() {' "$LIB"
grep -Fq 'oma2_evidence_exit() {' "$LIB"
grep -Fq "trap 'oma2_evidence_exit \"\$?\"' EXIT" "$LIB"
grep -Fq 'OMA2_EVIDENCE_FINALIZED=0' "$LIB"
grep -Fq 'oma2_evidence_finalize 1 "O.M.A.-2 exited unexpectedly while executing: ${BASH_COMMAND:-unknown}"' "$LIB"
grep -Fq 'sha256sum "$OMA2_EVIDENCE" > "$hash_tmp"' "$LIB"
grep -Fq 'mv -- "$hash_tmp" "$OMA2_EVIDENCE.sha256"' "$LIB"
grep -Fq 'oma2_evidence_finalize "$failures"' "$LIB"

printf '%s
' 'PASS: O.M.A.-2 evidence finalization contract'

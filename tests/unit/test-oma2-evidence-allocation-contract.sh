#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/tests/oma/lib/evidence.sh"

bash -n "$LIB"

grep -Fq 'OMA2_EVIDENCE="$(mktemp "$OMA2_EVIDENCE_DIR/oma2-$OMA2_TIMESTAMP-XXXXXX.txt")"' "$LIB"
grep -Fq 'OMA2_TMP="$(mktemp)"' "$LIB"

printf '%s
printf '%s\n' 'PASS: O.M.A.-2 evidence allocation contract'

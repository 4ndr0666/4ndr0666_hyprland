#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/oma/run-oma2.sh"

bash -n "$RUNNER"

evidence_dir_line="$(grep -nF 'EVIDENCE_DIR="$ROOT/oma-evidence"' "$RUNNER")"
oma2_evidence_dir_line="$(grep -nF 'OMA2_EVIDENCE_DIR="$EVIDENCE_DIR"' "$RUNNER")"
source_line="$(grep -nF 'source "$LIB_DIR/evidence.sh"' "$RUNNER")"

[[ -n "$evidence_dir_line" ]] || {
  printf '%s\n' 'FAIL: O.M.A.-2 evidence directory declaration is missing' >&2
  exit 1
}
[[ -n "$oma2_evidence_dir_line" ]] || {
  printf '%s\n' 'FAIL: OMA2_EVIDENCE_DIR declaration is missing' >&2
  exit 1
}
[[ -n "$source_line" ]] || {
  printf '%s\n' 'FAIL: evidence library source is missing' >&2
  exit 1
}

oma2_line="${oma2_evidence_dir_line%%:*}"
source_line_number="${source_line%%:*}"
(( oma2_line < source_line_number )) || {
  printf '%s\n' 'FAIL: OMA2_EVIDENCE_DIR must be initialized before evidence.sh is sourced' >&2
  exit 1
}

printf '%s\n' 'PASS: O.M.A.-2 evidence contract'

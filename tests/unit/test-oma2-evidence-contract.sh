#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/tests/oma/run-oma2.sh"
EVIDENCE_LIB="$ROOT/tests/oma/lib/evidence.sh"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

FAKE_ROOT="$TMPDIR/repo"
EVIDENCE_DIR="$TMPDIR/evidence"
mkdir -p "$FAKE_ROOT/tests/oma/lib" "$EVIDENCE_DIR"

cp -- "$RUNNER" "$FAKE_ROOT/tests/oma/run-oma2.sh"
cp -- "$EVIDENCE_LIB" "$FAKE_ROOT/tests/oma/lib/evidence.sh"
printf '%s\n' 'test-release' > "$FAKE_ROOT/release.ref"

sed -i 's#^ROOT=.*#ROOT="'$FAKE_ROOT'"#' "$FAKE_ROOT/tests/oma/run-oma2.sh"
sed -i 's#^EVIDENCE_DIR=.*#EVIDENCE_DIR="'$EVIDENCE_DIR'"#' "$FAKE_ROOT/tests/oma/run-oma2.sh"
sed -i '/source "$LIB_DIR\/evidence.sh"/a OMA2_EVIDENCE_DIR="$EVIDENCE_DIR"' "$FAKE_ROOT/tests/oma/run-oma2.sh"

bash -n "$FAKE_ROOT/tests/oma/run-oma2.sh"
bash -n "$FAKE_ROOT/tests/oma/lib/evidence.sh"

grep -Fqx 'OMA2_EVIDENCE_DIR="$EVIDENCE_DIR"' <(sed -n '/source "$LIB_DIR\/evidence.sh"/,/source "$LIB_DIR\/lifecycle.sh"/p' "$FAKE_ROOT/tests/oma/run-oma2.sh") ||
  { printf '%s\n' 'FAIL: evidence directory was not initialized before evidence library use' >&2; exit 1; }

printf '%s\n' 'PASS: O.M.A.-2 evidence contract'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="$ROOT/oma-evidence"
OMA2_EVIDENCE_DIR="$EVIDENCE_DIR"
LIB_DIR="$ROOT/tests/oma/lib"
MODE="${1:---safe}"

case "$MODE" in
  --safe|--destructive) ;;
  *)
    printf '[ERROR] Unsupported O.M.A.-2 mode: %s\n' "$MODE" >&2
    printf '%s\n' 'Usage: run-oma2.sh [--safe|--destructive]' >&2
    exit 2
    ;;
esac

for cmd in bash awk cat cp date grep mkdir mktemp mv rm sed sha256sum sleep flock systemctl busctl pidof uname id tr wc; do
  command -v "$cmd" >/dev/null 2>&1 || {
    printf '[ERROR] Required O.M.A.-2 command unavailable: %s\n' "$cmd" >&2
    exit 1
  }
done

[[ -x "$ROOT/tests/oma/run-oma1.sh" ]] || {
  printf '[ERROR] O.M.A.-1 runner is unavailable or not executable.\n' >&2
  exit 1
}

for script in \
  "$ROOT/tests/oma/run-oma1.sh" \
  "$ROOT/tests/oma/run-oma.sh" \
  "$ROOT/tests/oma/run-oma2.sh" \
  "$LIB_DIR/evidence.sh" \
  "$LIB_DIR/lifecycle.sh" \
  "$LIB_DIR/concurrency.sh" \
  "$LIB_DIR/interruption.sh" \
  "$LIB_DIR/recovery.sh"; do
  [[ -r "$script" ]] || {
    printf '[ERROR] O.M.A.-2 harness file missing: %s\n' "$script" >&2
    exit 1
  }
  bash -n "$script"
done

# shellcheck disable=SC1091
source "$LIB_DIR/evidence.sh"
# shellcheck disable=SC1091
source "$LIB_DIR/lifecycle.sh"
# shellcheck disable=SC1091
source "$LIB_DIR/concurrency.sh"
# shellcheck disable=SC1091
source "$LIB_DIR/interruption.sh"
# shellcheck disable=SC1091
source "$LIB_DIR/recovery.sh"

mkdir -p "$EVIDENCE_DIR"
oma2_evidence_init

oma2_emit "mode=oma2-${MODE#--}"
oma2_emit "timestamp=$OMA2_TIMESTAMP"
oma2_emit "hostname=$(uname -n)"
oma2_emit "user=$(id -un)"
oma2_emit "uid=$(id -u)"
oma2_emit "release_ref=$(tr -d '[:space:]' < "$ROOT/release.ref")"

failures=0
oma2_section prerequisites
oma2_probe harness_syntax bash -n "$ROOT/tests/oma/run-oma2.sh" || failures=$((failures + 1))
oma2_probe gup_suite bash "$ROOT/tests/unit/run-golden-units.sh" || failures=$((failures + 1))
oma2_probe oma1_baseline bash "$ROOT/tests/oma/run-oma1.sh" || failures=$((failures + 1))

if (( failures == 0 )); then
  oma2_lifecycle_safe || failures=$((failures + 1))
  oma2_concurrency || failures=$((failures + 1))
  oma2_interruption || failures=$((failures + 1))
  oma2_recovery || failures=$((failures + 1))

  if [[ "$MODE" == '--destructive' ]]; then
    if [[ "${OMA2_DESTRUCTIVE:-}" == 1 ]]; then
      oma2_emit 'destructive_gate=OPEN'
      oma2_lifecycle_destructive || failures=$((failures + 1))
    else
      oma2_emit 'destructive_gate=REJECTED'
      oma2_emit 'destructive_tests=NOT_RUN'
      oma2_emit 'destructive_reason=OMA2_DESTRUCTIVE=1 is required on a disposable certification host'
      failures=$((failures + 1))
    fi
  else
    oma2_emit 'destructive_gate=CLOSED'
    oma2_emit 'destructive_tests=NOT_RUN'
  fi
else
  oma2_emit 'oma2_execution=BLOCKED_BY_PREREQUISITES'
fi

if oma2_finish "$failures"; then
  printf '[PASS] O.M.A.-2 %s harness completed with zero observed failures.\n' "$MODE"
else
  printf '[FAIL] O.M.A.-2 %s harness observed %s failure(s).\n' "$MODE" "$failures" >&2
  exit 1
fi

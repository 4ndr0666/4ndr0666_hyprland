#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/config/hypr/scripts/Tak0-Autodispatch.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$SCRIPT" ]] || fail "autodispatch script is missing"
grep -Fq 'set -Eeuo pipefail' "$SCRIPT" || fail "autodispatch does not fail closed"
grep -Fq 'trap cleanup EXIT INT TERM' "$SCRIPT" || fail "autodispatch cleanup trap is missing"
grep -Fq 'Hyprland did not become ready within 5 seconds' "$SCRIPT" || fail "autodispatch readiness failure is not loud"
! grep -Fq 'TO-DO' "$SCRIPT" || fail "autodispatch retains unfinished TODO state"
grep -Fq '"${CMD[@]}" &' "$SCRIPT" || fail "autodispatch command boundary is not argv-safe"

printf 'PASS: autodispatch has explicit readiness, argv-safe launch, and unconditional cleanup contracts\n'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HARNESS="$ROOT/tests/oma/run-oma.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -f "$HARNESS" ]] || fail "O.M.A. harness is missing"
grep -Fq 'version=1.1' "$HARNESS" || fail "harness is not aligned with O.M.A. v1.1"
grep -Fq 'hostname=%s\\n' "$HARNESS" || fail "hostname evidence field is missing"
grep -Fq '"$(uname -n)"' "$HARNESS" || fail "hostname evidence must use uname -n"
! grep -Fq '$(hostname)' "$HARNESS" || fail "harness must not depend on hostname"
! grep -Fq 'exit || true' "$HARNESS" || fail "awk probes must not contain shell fallback syntax"
! grep -Fq ' | paste ' "$HARNESS" || fail "harness must not introduce an undeclared paste dependency"
grep -Fq 'PACMAN_VERSION=' "$HARNESS" || fail "pacman evidence must be captured explicitly"
grep -Fq '/Pacman v/' "$HARNESS" || fail "pacman evidence must identify the pacman version"
grep -Fq 'Required O.M.A. evidence field is empty' "$HARNESS" || fail "required evidence fields must fail closed when empty"
grep -Fq 'dns_nameservers=' "$HARNESS" || fail "DNS configuration evidence is missing"
grep -Fq 'memory_kb=' "$HARNESS" || fail "memory evidence is missing"

for cmd in bash awk findmnt lspci lscpu pacman systemctl ip git date mktemp mv tr; do
  grep -Fq "for cmd in bash awk findmnt lspci lscpu pacman systemctl ip git date mktemp mv tr" "$HARNESS" || fail "required capability inventory is incomplete"
done

printf '%s\n' 'O.M.A. harness contract: PASS'

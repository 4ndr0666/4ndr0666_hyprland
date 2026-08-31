#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALLER="$ROOT/install.sh"

[[ -f "$INSTALLER" ]] || { printf '[FAIL] Missing install.sh\n' >&2; exit 1; }

grep -Eq '^set -Eeuo pipefail$' "$INSTALLER" || {
  printf '[FAIL] install.sh does not enable fail-closed shell execution.\n' >&2
  exit 1
}

grep -Eq '^run_module\(\)' "$INSTALLER" || {
  printf '[FAIL] install.sh lacks canonical run_module execution boundary.\n' >&2
  exit 1
}

grep -Eq 'run_module 00-base\.sh' "$INSTALLER" || {
  printf '[FAIL] Canonical base module is not executed through run_module.\n' >&2
  exit 1
}

grep -Eq 'run_module 02-Final-Check\.sh' "$INSTALLER" || {
  printf '[FAIL] Final verification is not executed through run_module.\n' >&2
  exit 1
}

if grep -Eq '(^|[[:space:];])execute_script[[:space:]]' "$INSTALLER"; then
  printf '[FAIL] Direct execute_script orchestration remains in install.sh.\n' >&2
  exit 1
fi

printf '[PASS] install.sh uses the canonical fail-closed module execution boundary.\n'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/golden-units.yml"

[[ -f "$WORKFLOW" ]] || { printf '%s\n' 'missing Golden Unit workflow' >&2; exit 1; }

grep -Eq 'uses:[[:space:]]*actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09[[:space:]]+# v5\.1\.0$' "$WORKFLOW" || {
  printf '%s\n' 'Golden Unit checkout action is not pinned to the Node24-compatible immutable commit' >&2
  exit 1
}

if grep -Eq 'uses:[[:space:]]*actions/checkout@v' "$WORKFLOW"; then
  printf '%s\n' 'mutable checkout action tag remains' >&2
  exit 1
fi

printf '%s\n' 'GitHub Actions Node24 pinning boundary: PASS'

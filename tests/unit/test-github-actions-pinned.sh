#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/golden-units.yml"

[[ -f "$WORKFLOW" ]] || { printf '%s\n' 'missing Golden Unit workflow' >&2; exit 1; }

grep -Eq 'uses:[[:space:]]*actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1[[:space:]]+# v7\.0\.1$' "$WORKFLOW" || {
  printf '%s\n' 'Golden Unit checkout action is not pinned to the latest Node24-compatible immutable commit' >&2
  exit 1
}

if grep -Eq 'uses:[[:space:]]*actions/checkout@v' "$WORKFLOW"; then
  printf '%s\n' 'mutable checkout action tag remains' >&2
  exit 1
fi

printf '%s\n' 'GitHub Actions Node24 pinning boundary: PASS'

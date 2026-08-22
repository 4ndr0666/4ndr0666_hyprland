#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKAGES="$ROOT/install-scripts/core/packages.sh"

if grep -Eq 'pacman[[:space:]].*-Sy([^u]|$)' "$PACKAGES"; then
  echo 'unsafe pacman -Sy detected; use a full upgrade' >&2
  exit 1
fi

grep -Eq 'pacman[[:space:]].*-Syu' "$PACKAGES"

echo 'pacman sync invariant: PASS'

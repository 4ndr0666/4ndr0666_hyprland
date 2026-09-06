#!/usr/bin/env bash
# Golden Unit: the canonical bootstrap must consume the repository release.ref.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE_REF_FILE="$ROOT/release.ref"
BOOTSTRAP="$ROOT/Distro-Hyprland.sh"

ref="$(tr -d '[:space:]' < "$RELEASE_REF_FILE")"
[[ "$ref" =~ ^[0-9a-fA-F]{40}$ ]] || {
  printf '[FAIL] release.ref is not exactly one 40-character commit SHA.\n' >&2
  exit 1
}

grep -Fq 'DEFAULT_REF_FILE="$BOOTSTRAP_DIR/release.ref"' "$BOOTSTRAP" || {
  printf '[FAIL] Distro-Hyprland.sh does not use release.ref as its default revision source.\n' >&2
  exit 1
}

grep -Fq 'INSTALL_REF="${HYPRLAND_INSTALL_REF:-}"' "$BOOTSTRAP" || {
  printf '[FAIL] bootstrap override contract is missing.\n' >&2
  exit 1
}

if grep -Eq "RELEASE_REF=\"[0-9a-fA-F]{40}\"" "$BOOTSTRAP"; then
  printf '[FAIL] bootstrap contains a duplicated hard-coded release revision.\n' >&2
  exit 1
fi

printf '[PASS] canonical bootstrap consumes release.ref without duplicating the revision.\n'

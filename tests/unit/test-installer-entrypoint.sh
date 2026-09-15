#!/usr/bin/env bash
# Golden Unit: installer entry-point architecture checks.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALLER="$ROOT/install.sh"
PACMAN_MODULE="$ROOT/install-scripts/pacman.sh"
FINAL_CHECK="$ROOT/install-scripts/02-Final-Check.sh"
MANIFEST="$ROOT/install-scripts/core/package-manifest.sh"

# install.sh may query package state, but package mutation must go through core.
if grep -Eq '(^|[[:space:]])(sudo[[:space:]]+)?pacman[[:space:]]+-S|(^|[[:space:]])(sudo[[:space:]]+)?pacman[[:space:]]+-R' "$INSTALLER"; then
  printf '%s\n' 'installer entry point contains direct package mutation' >&2
  exit 1
fi

grep -Fq 'source "$SCRIPT_DIR/core/package-manifest.sh"' "$INSTALLER"
grep -Fq 'package_install "${INSTALLER_RUNTIME_PACKAGES[@]}"' "$INSTALLER"
grep -Fq 'libnewt' "$MANIFEST"
grep -Fq 'pciutils' "$MANIFEST"
grep -Fq 'source "$SCRIPT_DIR/core/packages.sh"' "$PACMAN_MODULE"
! grep -Fq 'Global_functions.sh' "$PACMAN_MODULE"
! grep -Fq 'Global_functions.sh' "$FINAL_CHECK"

printf '%s\n' 'installer-entrypoint: PASS'

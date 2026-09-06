#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BOOTSTRAP="$ROOT/Distro-Hyprland.sh"

# There must be one bootstrap authority for the current repository.
grep -Fq 'REPOSITORY_URL="https://github.com/4ndr0666/4ndr0666_hyprland.git"' "$BOOTSTRAP"
grep -Fq 'DEFAULT_REF_FILE="$BOOTSTRAP_DIR/release.ref"' "$BOOTSTRAP"
grep -Fq 'INSTALL_REF="${HYPRLAND_INSTALL_REF:-}"' "$BOOTSTRAP"
grep -Fq 'git fetch --depth=1 origin "$INSTALL_REF"' "$BOOTSTRAP"
grep -Fq 'git checkout --detach --force "$INSTALL_REF"' "$BOOTSTRAP"
grep -Fq 'actual_ref="$(git rev-parse HEAD)"' "$BOOTSTRAP"

if grep -Eq 'Arch-Hyprland\.git|Distro_DIR=|RELEASE_REF="[0-9a-fA-F]{40}"' "$BOOTSTRAP"; then
  printf '%s\n' '[FAIL] bootstrap retains a legacy repository/path/ref authority.' >&2
  exit 1
fi

if grep -Eq 'git pull|git merge|git checkout main|git checkout master' "$BOOTSTRAP"; then
  printf '%s\n' '[FAIL] bootstrap contains a mutable update path.' >&2
  exit 1
fi

printf '%s\n' '[PASS] current bootstrap is the sole repository/revision authority.'

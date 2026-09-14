#!/usr/bin/env bash
# Golden Unit: Arch-family platform detection.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/install-scripts/core/platform.sh"

is_arch_family arch ''
is_arch_family manjaro 'arch'
is_arch_family endeavouros 'arch'
is_arch_family artix 'arch'

if is_arch_family ubuntu 'debian'; then
  printf '%s\n' 'arch-family-detection: FAIL non-Arch host accepted' >&2
  exit 1
fi

if is_arch_family '' ''; then
  printf '%s\n' 'arch-family-detection: FAIL empty identity accepted' >&2
  exit 1
fi

printf '%s\n' 'arch-family-detection: PASS'

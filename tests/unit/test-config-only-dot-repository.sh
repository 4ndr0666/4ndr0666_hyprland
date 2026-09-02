#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

[[ -f config/hypr/v2.3.20 ]] || { printf '%s\n' 'config dotfiles reference missing' >&2; exit 1; }
[[ ! -e config/hypr/scripts/4ndr0666DotsUpdate.sh ]] || { printf '%s\n' 'external dot updater remains' >&2; exit 1; }
[[ ! -e update-dots.sh ]] || { printf '%s\n' 'repository dot updater remains' >&2; exit 1; }
! grep -RInE --exclude-dir=.git --exclude='test-config-only-dot-repository.sh' \
  'JaKooLit/Hyprland-Dots|KooL_Dots_DIR|Hyprland-Dots\.git' . >/dev/null
! grep -Fq 'Stash + git pull' scripts/copy_menu.sh
! grep -Fq 'Update  -' scripts/copy_menu.sh

printf '%s\n' 'config-only dot repository boundary: PASS'

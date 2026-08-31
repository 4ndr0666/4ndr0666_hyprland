#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

legacy_paths=(
  assets/hyprland-install/actions.sh
  assets/hyprland-install/uninstall.sh
  assets/hyprland-install/scripts/install-hyprland.sh
  assets/hyprland-install/scripts/install-hyprland-git.sh
  assets/hyprland-install/scripts/uninstall.sh
)

for path in "${legacy_paths[@]}"; do
  [[ ! -e "$path" ]] || { printf '[FAIL] Legacy installer path remains: %s\n' "$path" >&2; exit 1; }
done

if git grep -n -E 'assets/hyprland-install/(actions\.sh|uninstall\.sh|scripts/(install-hyprland|install-hyprland-git|uninstall)\.sh)' -- . ':!tests/unit/test-legacy-installer-removal.sh'; then
  printf '[FAIL] Repository still references removed legacy installer entry points.\n' >&2
  exit 1
fi

printf '[PASS] Legacy Hyprland installer entry points are absent and unreferenced.\n'

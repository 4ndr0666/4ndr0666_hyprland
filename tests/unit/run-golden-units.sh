#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TESTS=(
  tests/unit/test-packages.sh
  tests/unit/test-package-manifest-atomicity.sh
  tests/unit/test-pacman-sync-invariant.sh
  tests/unit/test-systemd.sh
  tests/unit/test-files.sh
  tests/unit/test-dotfiles.sh
  tests/unit/test-dotfile-backup-atomicity.sh
  tests/unit/test-dotfile-destructive-patterns.sh
  tests/unit/test-bootstrap.sh
  tests/unit/test-bootstrap-docs.sh
  tests/unit/test-bootstrap-authority.sh
  tests/unit/test-release-ref-consistency.sh
  tests/unit/test-aur-bootstrap.sh
  tests/unit/test-installer-entrypoint.sh
  tests/unit/test-installer-fail-closed.sh
  tests/unit/test-package-boundary.sh
  tests/unit/test-legacy-installer-removal.sh
  tests/unit/test-no-legacy-install-package.sh
  tests/unit/test-remote-exec-invariant.sh
  tests/unit/test-self-update-boundary.sh
  tests/unit/test-sddm-rollback.sh
  tests/unit/test-copy-orchestration-boundary.sh
  tests/unit/test-copy-phase1-atomicity.sh
  tests/unit/test-copy-transaction-runtime.sh
  tests/unit/test-copy-source-immutability.sh
  tests/unit/test-copy-cwd-portability.sh
  tests/unit/test-config-only-dot-repository.sh
  tests/unit/test-github-actions-pinned.sh
  tests/unit/test-waybar-script-config-boundary.sh
  tests/unit/test-waybar-symlink-restoration.sh
  tests/unit/test-rofi-search-config-boundary.sh
  tests/unit/test-wallpaper-effect-config-boundary.sh
  tests/unit/test-compositor-shell-installers.sh
  tests/unit/test-waybar-wallust-pipeline.sh
  tests/unit/test-waybar-wallust-orchestration.sh
  tests/unit/test-gamemode-wallust-boundary.sh
  tests/unit/test-quickshell-overview-boundary.sh
  tests/unit/test-ags-retirement-boundary.sh
  tests/unit/test-runtime-orchestration-boundaries.sh
  tests/unit/test-current-tree-integrity.sh
  tests/unit/test-quickshell-overview-single-source.sh
  tests/unit/test-runtime-path-integrity.sh
  tests/unit/test-weather-fallback-boundary.sh
  tests/unit/test-gup-capability-contract-matrix.sh
  tests/unit/test-keybind-reachability.sh
  tests/unit/test-keybind-parser-lua-authority.sh
  tests/unit/test-cava-lifecycle.sh
  tests/unit/test-portal-lifecycle.sh
  tests/unit/test-documentation-current-authority.sh
  tests/unit/test-uninstall-symmetry-contract.sh
  tests/unit/test-capability-superset-contract.sh
  tests/unit/test-rofi-runtime-connectivity.sh
  tests/unit/test-swaync-runtime-connectivity.sh
  tests/unit/test-terminal-config-connectivity.sh
  tests/unit/test-monitor-user-config-connectivity.sh
  tests/unit/test-asset-deployment-connectivity.sh
  tests/unit/test-autodispatch-lifecycle.sh
)

failures=()

for test in "${TESTS[@]}"; do
  printf '\n=== %s ===\n' "$test"
  if bash "$ROOT/$test"; then
    printf '[PASS] %s\n' "$test"
  else
    failures+=("$test")
    printf '[FAIL] %s\n' "$test" >&2
  fi
done

printf '\n=== Golden Unit Summary ===\n'
printf 'Total: %d\n' "${#TESTS[@]}"
printf 'Failed: %d\n' "${#failures[@]}"

if ((${#failures[@]})); then
  printf 'Failed units:\n' >&2
  printf ' - %s\n' "${failures[@]}" >&2
  exit 1
fi

printf 'All Golden Units passed.\n'

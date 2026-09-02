#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QUICKSHELL_INSTALLER="$ROOT/install-scripts/quickshell.sh"
AGS_INSTALLER="$ROOT/install-scripts/ags.sh"
AGS_LAUNCHER="$ROOT/install-scripts/ags.launcher.com.github.Aylur.ags"

[[ -f "$QUICKSHELL_INSTALLER" ]]
[[ ! -e "$AGS_INSTALLER" ]]
[[ ! -e "$AGS_LAUNCHER" ]]

grep -Fq 'set -Eeuo pipefail' "$QUICKSHELL_INSTALLER"
grep -Fq 'source "$SCRIPT_DIR/core/packages.sh"' "$QUICKSHELL_INSTALLER"
grep -Fq 'package_install qt6-5compat quickshell' "$QUICKSHELL_INSTALLER"
grep -Fq 'command -v qs' "$QUICKSHELL_INSTALLER"
grep -Fq 'package_is_installed quickshell' "$QUICKSHELL_INSTALLER"

! grep -Fq 'source ./preset.sh' "$QUICKSHELL_INSTALLER"
! grep -Fq 'git clone' "$QUICKSHELL_INSTALLER"
! grep -Fq 'npm install' "$QUICKSHELL_INSTALLER"
! grep -Fq 'meson setup' "$QUICKSHELL_INSTALLER"
! grep -Fq 'sudo meson install' "$QUICKSHELL_INSTALLER"
! grep -Fq 'rm -rf' "$QUICKSHELL_INSTALLER"

printf '%s\n' 'Quickshell/AGS installer boundary: PASS'

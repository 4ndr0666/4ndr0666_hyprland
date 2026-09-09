#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALLER="$ROOT/install-scripts/sddm_theme.sh"
ASSETS="$ROOT/assets/sddm"

[[ -f "$INSTALLER" ]] || { printf '[FAIL] Missing SDDM theme installer.\n' >&2; exit 1; }
[[ -d "$ASSETS" ]] || { printf '[FAIL] Missing native SDDM asset directory.\n' >&2; exit 1; }
for required in Main.qml theme.conf sessionsDetector.sh; do
  [[ -f "$ASSETS/$required" ]] || { printf '[FAIL] Missing native SDDM asset: %s.\n' "$required" >&2; exit 1; }
done

grep -Fq 'ASSET_THEME_DIR="$PARENT_DIR/assets/sddm"' "$INSTALLER"
grep -Fq 'cp -a -- "$ASSET_THEME_DIR/." "$STAGED_THEME/"' "$INSTALLER"
grep -Fq 'sessionsDetector.sh' "$INSTALLER"
grep -Fq 'sessions.txt' "$INSTALLER"
grep -Fq 'timeout --signal=TERM --kill-after=30s' "$INSTALLER"
grep -Fq 'trap cleanup EXIT INT TERM HUP' "$INSTALLER"
! grep -Fq 'simple-sddm-2.git' "$INSTALLER"
! grep -Fq 'terminal-inspired-sddm-theme.git' "$INSTALLER"
! grep -Fq 'git clone' "$INSTALLER"
! grep -Fq 'assets/sddm.png' "$INSTALLER"
! grep -Fq 'Backgrounds/default' "$INSTALLER"
! grep -Fq '|| true' "$INSTALLER"

bash -n "$INSTALLER"
printf '[PASS] SDDM installer consumes native assets without remote theme cloning or obsolete background assumptions.\n'

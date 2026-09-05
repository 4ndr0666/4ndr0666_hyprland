#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-copy-test.XXXXXX")"
cleanup() { rm -rf -- "$TMP_HOME"; }
trap cleanup EXIT INT TERM HUP

export HOME="$TMP_HOME"
cd "$ROOT"

source "$ROOT/scripts/lib_backup.sh"
source "$ROOT/scripts/lib_copy.sh"
install_terminal_configs() { :; }
version_gte() { [[ "$1" == "$2" ]]; }

mkdir -p "$HOME/.config/hypr"
printf '%s\n' 'sentinel-from-existing-installation' > "$HOME/.config/hypr/UserSettings.conf"
printf '%s\n' '[test]' > "$TMP_HOME/copy.log"

copy_phase2 "$TMP_HOME/copy.log"

[[ -d "$HOME/.config/hypr" ]]
[[ -f "$HOME/.config/hypr/UserSettings.conf" ]]
[[ "$(cat "$HOME/.config/hypr/UserSettings.conf")" != 'sentinel-from-existing-installation' ]]
[[ -n "$LAST_HYPR_BACKUP_PATH" ]]
[[ -d "$LAST_HYPR_BACKUP_PATH" ]]
[[ -f "$LAST_HYPR_BACKUP_PATH/UserSettings.conf" ]]
[[ "$(cat "$LAST_HYPR_BACKUP_PATH/UserSettings.conf")" == 'sentinel-from-existing-installation' ]]

printf '[PASS] copy_phase2 preserves the exact Hypr backup path for restore stages.\n'

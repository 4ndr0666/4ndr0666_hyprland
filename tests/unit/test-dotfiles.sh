#!/bin/bash
# Golden Unit Protocol: dotfile ownership contract tests.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORE="$ROOT/install-scripts/core/dotfiles.sh"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

FAKE_HOME="$TMPDIR/home/user"
SOURCE="$TMPDIR/repo/config"
MANIFEST="$TMPDIR/files.manifest"
BACKUPS="$TMPDIR/backups"
mkdir -p "$FAKE_HOME/.config/test" "$SOURCE" "$BACKUPS"

printf '%s\n' old > "$FAKE_HOME/.config/test/value"
printf '%s\n' new > "$SOURCE/value"

export HOME="$FAKE_HOME"
export INSTALLER_FILE_MANIFEST="$MANIFEST"
export INSTALLER_BACKUP_ROOT="$BACKUPS"
source "$CORE"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

dotfiles_replace "$SOURCE" "$HOME/.config/test"
[[ "$(cat "$HOME/.config/test/value")" == new ]] || fail 'dotfile replacement failed'
grep -F $'replaced\t' "$MANIFEST" >/dev/null || fail 'dotfile ownership was not recorded'

BACKUP_PATH="$(awk -F '\t' '$1 == "replaced" { print $3; exit }' "$MANIFEST")"
[[ -f "$BACKUP_PATH/value" ]] || fail 'dotfile backup was not created'
[[ "$(cat "$BACKUP_PATH/value")" == old ]] || fail 'dotfile backup did not preserve original'

if dotfiles_replace "$SOURCE" "$TMPDIR/outside"; then
  fail 'dotfile primitive accepted destination outside HOME'
fi

file_state_restore_manifest
[[ "$(cat "$HOME/.config/test/value")" == old ]] || fail 'dotfile restore failed'

printf 'PASS: dotfile core\n'

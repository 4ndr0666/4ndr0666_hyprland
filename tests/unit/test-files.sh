#!/bin/bash
# Golden Unit Protocol: file-state contract tests.
# Exercises files and directories in disposable fixtures only.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORE="$ROOT/install-scripts/core/files.sh"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

SOURCE="$TMPDIR/source"
DEST="$TMPDIR/dest"
MANIFEST="$TMPDIR/files.manifest"
BACKUPS="$TMPDIR/backups"
mkdir -p "$SOURCE" "$DEST" "$BACKUPS"

printf '%s\n' original > "$DEST/value"
printf '%s\n' replacement > "$SOURCE/value"
printf '%s\n' untouched > "$DEST/untouched"

export INSTALLER_FILE_MANIFEST="$MANIFEST"
export INSTALLER_BACKUP_ROOT="$BACKUPS"
source "$CORE"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

file_state_atomic_replace "$SOURCE/value" "$DEST/value"
[[ "$(cat "$DEST/value")" == replacement ]] || fail 'file replacement failed'
grep -F $'replaced\t' "$MANIFEST" >/dev/null || fail 'replacement was not recorded'

BACKUP_PATH="$(awk -F '\t' '$1 == "replaced" { print $3; exit }' "$MANIFEST")"
[[ -f "$BACKUP_PATH" ]] || fail 'replacement backup was not created'
[[ "$(cat "$BACKUP_PATH")" == original ]] || fail 'backup did not preserve original file'

mkdir -p "$SOURCE/tree/sub"
printf '%s\n' nested > "$SOURCE/tree/sub/value"
file_state_atomic_replace "$SOURCE/tree" "$DEST/tree"
[[ -f "$DEST/tree/sub/value" ]] || fail 'directory replacement failed'
[[ "$(cat "$DEST/tree/sub/value")" == nested ]] || fail 'directory contents were not copied'

grep -F $'replaced\t' "$MANIFEST" | grep -F $'\t' >/dev/null || fail 'directory replacement was not recorded'

file_state_restore_manifest
[[ "$(cat "$DEST/value")" == original ]] || fail 'file restore failed'
[[ ! -e "$DEST/tree" ]] || fail 'created/replaced directory was not restored correctly'
[[ "$(cat "$DEST/untouched")" == untouched ]] || fail 'unrelated file was modified'

printf 'PASS: file-state core\n'

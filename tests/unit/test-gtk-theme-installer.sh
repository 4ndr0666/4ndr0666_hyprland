#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT_DIR/install-scripts/gtk_themes.sh"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

[[ -f "$FILE" ]] || fail 'GTK theme installer is missing.'
grep -Fq 'set -Eeuo pipefail' "$FILE" || fail 'GTK theme installer is not strict.'
grep -Fq 'JaKooLit/GTK-themes-icons.git' "$FILE" || fail 'GTK theme source is not the known canonical repository.'
grep -Eq 'GTK_REPOSITORY_REVISION="[0-9a-f]{40}"' "$FILE" || fail 'GTK theme dependency is not pinned to a full commit.'
grep -Fq 'timeout --signal=TERM --kill-after=30s' "$FILE" || fail 'GTK git operations lack bounded execution.'
grep -Fq 'mktemp -d' "$FILE" || fail 'GTK installation lacks isolated staging.'
grep -Fq 'trap cleanup EXIT INT TERM HUP' "$FILE" || fail 'GTK installation lacks unconditional cleanup.'
grep -Fq 'rev-parse HEAD' "$FILE" || fail 'GTK revision verification is missing.'
grep -Fq 'actual_revision" == "$GTK_REPOSITORY_REVISION"' "$FILE" || fail 'GTK revision verification is not fail-closed.'
! grep -Eq 'git clone .*4ndr0666/GTK-themes-icons' "$FILE" || fail 'Removed GTK source is still referenced.'
! grep -Fq 'rm -rf "GTK-themes-icons"' "$FILE" || fail 'Destructive repository cleanup remains.'
! grep -Fq 'if git clone' "$FILE" || fail 'GTK clone still has conditional-success semantics.'
! grep -Fq 'Download failed' "$FILE" || fail 'GTK download failure is still swallowed.'
bash -n "$FILE"
printf '%s\n' 'GTK theme installer boundary: PASS'

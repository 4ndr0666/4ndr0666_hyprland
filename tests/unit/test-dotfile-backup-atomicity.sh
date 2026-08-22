#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib_backup.sh"

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT

mkdir -p "$TMP/source" "$TMP/destination"
printf 'new\n' > "$TMP/source/config"
printf 'old\n' > "$TMP/destination/config"

backup="$(replace_dir_transaction "$TMP/source" "$TMP/destination")"
[[ -d "$TMP/destination" ]]
[[ "$(cat "$TMP/destination/config")" == new ]]
[[ -n "$backup" && -d "$backup" ]]
[[ "$(cat "$backup/config")" == old ]]

mkdir -p "$TMP/source2"
printf 'replacement\n' > "$TMP/source2/config"

if replace_dir_transaction "$TMP/missing-source" "$TMP/destination" >/dev/null 2>&1; then
  echo 'missing source unexpectedly succeeded' >&2
  exit 1
fi
[[ "$(cat "$TMP/destination/config")" == new ]]

echo 'dotfile backup atomicity: PASS'

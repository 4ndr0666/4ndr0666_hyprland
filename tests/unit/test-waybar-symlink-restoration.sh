#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/scripts/lib_copy.sh"

content="$(cat "$FILE")"

# Waybar backups may contain relative symlink targets. Resolution must be
# relative to the backup symlink's containing directory, not the caller CWD.
grep -Fq 'symlink_target="$(readlink -- "$symlink")"' "$FILE"
grep -Fq 'symlink_dir="$(dirname -- "$symlink")"' "$FILE"
grep -Fq 'target_file="$symlink_dir/$symlink_target"' "$FILE"

# The restoration copy must consume the resolved target path.
grep -Fq 'cp -f -- "$target_file" "$dir_path/$file"' "$FILE"

grep -Fq 'local file symlink symlink_target symlink_dir target_file' "$FILE"

printf '[PASS] Waybar symlink restoration resolves relative targets from the backup symlink directory.\n'

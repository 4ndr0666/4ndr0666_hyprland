#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib_backup.sh"
source "$ROOT/scripts/lib_copy.sh"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home"
for mode in 0 1; do
  root="$HOME/.config/hypr"
  mkdir -p "$root/UserScripts" "$tmp/old-$mode/UserScripts/nested"
  printf 'default\n' > "$root/UserScripts/default.sh"
  printf 'default conflict\n' > "$root/UserScripts/conflict.sh"
  printf 'personal conflict\n' > "$tmp/old-$mode/UserScripts/conflict.sh"
  printf 'personal\n' > "$tmp/old-$mode/UserScripts/nested/custom.sh"
  chmod 751 "$tmp/old-$mode/UserScripts/nested/custom.sh"
  ln -s nested/custom.sh "$tmp/old-$mode/UserScripts/link"
  LAST_HYPR_BACKUP_PATH="$tmp/old-$mode"
  restore_user_scripts "$tmp/log" "$mode"
  [[ $(cat "$root/UserScripts/default.sh") == default ]]
  [[ $(cat "$root/UserScripts/conflict.sh") == "personal conflict" ]]
  cmp "$tmp/old-$mode/UserScripts/nested/custom.sh" "$root/UserScripts/nested/custom.sh"
  [[ $(stat -c %a "$root/UserScripts/nested/custom.sh") == 751 ]]
  [[ $(readlink "$root/UserScripts/link") == nested/custom.sh ]]
  rm -rf -- "$root"
done

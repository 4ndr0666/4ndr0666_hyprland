#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib_backup.sh"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME/.config/hypr" "$HOME/.config/hypr-backup-old" "$HOME/.config/hypr-backup-new"
printf old > "$HOME/.config/hypr-backup-old/personal"
printf new > "$HOME/.config/hypr-backup-new/personal"
cleanup_backups auto "$tmp/log"
[[ $(cat "$HOME/.config/hypr-backup-old/personal") == old ]]
[[ $(cat "$HOME/.config/hypr-backup-new/personal") == new ]]

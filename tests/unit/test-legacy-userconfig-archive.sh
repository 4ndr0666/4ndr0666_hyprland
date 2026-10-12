#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/lib_copy.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/gup-legacy-userconfigs.XXXXXX")"
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

export HOME="$tmp/home"
log="$tmp/audit.log"
source_root="$tmp/old/UserConfigs"
archive_root="$HOME/.config/hypr/UserConfigs/legacy-conf-backup"
mkdir -p "$source_root/nested" "$source_root/legacy-conf-backup" "$HOME/.config/hypr/UserConfigs"
printf '%s\n' 'exec-once = old-startup' >"$source_root/Startup_Apps.conf"
printf '%s\n' 'bind = SUPER, X, exec, old-command' >"$source_root/nested/UserKeybinds.conf"
printf '%s\n' 'old archive copy' >"$source_root/legacy-conf-backup/already-archived.conf"
printf '%s\n' 'hl.env("EDITOR", "nvim")' >"$source_root/01-UserDefaults.lua"

archive_legacy_conf_files "$source_root" "$archive_root" "$log"
[[ -f "$archive_root/Startup_Apps.conf" ]] || fail 'legacy startup config was not preserved'
[[ -f "$archive_root/nested/UserKeybinds.conf" ]] || fail 'nested legacy config was not preserved'
[[ ! -e "$archive_root/legacy-conf-backup/already-archived.conf" ]] || fail 'existing archive was recursively copied'
[[ ! -e "$archive_root/01-UserDefaults.lua" ]] || fail 'Lua user configuration was misclassified as legacy'

archive_legacy_conf_files "$source_root" "$archive_root" "$log"
[[ "$(find "$archive_root" -type f -name 'Startup_Apps.conf*' | wc -l)" -eq 1 ]] ||
  fail 'repeated archive pass created a duplicate for identical content'

active="$HOME/.config/hypr/UserConfigs"
printf '%s\n' 'exec-once = stale-startup' >"$active/Startup_Apps.conf"
version_gte() { [[ "$1" == 2.3.20 ]]; }
cleanup_duplicate_userconfigs "2.3.20" "$log"
[[ ! -e "$active/Startup_Apps.conf" ]] || fail 'inactive .conf remained in active UserConfigs'
[[ -f "$active/legacy-conf-backup/Startup_Apps.conf" ]] || fail 'active legacy config was not archived'
grep -Fq 'does not load it automatically' "$log" || fail 'archive warning did not explain inactive runtime status'

printf '%s\n' 'legacy-userconfig-archive: PASS'

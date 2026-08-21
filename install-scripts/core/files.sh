#!/bin/bash
# File-state primitives. Domain-specific, intentionally small.

set -Eeuo pipefail

STATE_MANIFEST="${INSTALLER_FILE_MANIFEST:-${XDG_STATE_HOME:-$HOME/.local/state}/4ndr0666-hyprland/files.manifest}"
BACKUP_ROOT="${INSTALLER_BACKUP_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/4ndr0666-hyprland/backups}"

file_state_init() {
  mkdir -p -- "$(dirname "$STATE_MANIFEST")" "$BACKUP_ROOT"
  touch -- "$STATE_MANIFEST"
}

file_state_record() {
  local action="$1" path="$2" backup="${3:-}" before="${4:-}" after="${5:-}"
  file_state_init
  printf '%s\t%s\t%s\t%s\t%s\n' "$action" "$path" "$backup" "$before" "$after" >> "$STATE_MANIFEST"
}

file_state_hash() {
  sha256sum -- "$1" | awk '{print $1}'
}

file_state_backup() {
  local path="$1" backup
  file_state_init
  [[ -e "$path" || -L "$path" ]] || return 0
  backup="$BACKUP_ROOT/$(printf '%s' "$path" | sed 's#^/##; s#[/]#_#g').$(date +%Y%m%d%H%M%S).bak"
  cp -a -- "$path" "$backup"
  printf '%s\n' "$backup"
}

file_state_restore() {
  local path="$1" backup="$2"
  [[ -e "$backup" || -L "$backup" ]] || return 1
  if [[ -d "$backup" ]]; then
    rm -rf -- "$path"
    cp -a -- "$backup" "$path"
  else
    mkdir -p -- "$(dirname "$path")"
    cp -a -- "$backup" "$path"
  fi
}

file_state_atomic_replace() {
  local source="$1" destination="$2" backup="" before="" after
  file_state_init
  [[ -e "$source" || -L "$source" ]] || { printf '%s\n' "missing source: $source" >&2; return 1; }

  if [[ -e "$destination" || -L "$destination" ]]; then
    before="$(file_state_hash "$destination")"
    backup="$(file_state_backup "$destination")"
  fi

  local tmp
  tmp="$(mktemp --tmpdir="$(dirname "$destination")" .installer.XXXXXX)"
  rm -f -- "$tmp"
  cp -a -- "$source" "$tmp"
  mv -Tf -- "$tmp" "$destination"
  after="$(file_state_hash "$destination")"

  if [[ -n "$backup" ]]; then
    file_state_record replaced "$destination" "$backup" "$before" "$after"
  else
    file_state_record created "$destination" "" "" "$after"
  fi
}

file_state_restore_manifest() {
  file_state_init
  local action path backup before after
  while IFS=$'\t' read -r action path backup before after; do
    [[ -n "$action" ]] || continue
    case "$action" in
      replaced) file_state_restore "$path" "$backup" ;;
      created)
        [[ -e "$path" || -L "$path" ]] && rm -rf -- "$path"
        ;;
    esac
  done < "$STATE_MANIFEST"
}

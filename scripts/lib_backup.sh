#!/usr/bin/env bash
# === 4ndr0666 === #
# Backup helper utilities shared by copy.sh.

set -Eeuo pipefail

get_backup_dirname() {
  printf 'back-up_%s\n' "$(date +%m%d_%H%M%S)"
}

# Atomically move an existing directory into a sibling backup.
# The source remains untouched if the move cannot be completed.
backup_dir() {
  local dir="$1"
  local log="${2:-/dev/null}"
  local backup

  [[ -n "$dir" ]] || return 1
  [[ -d "$dir" ]] || return 1

  backup="${dir}-backup-$(get_backup_dirname)"
  mv -- "$dir" "$backup" 2>&1 | tee -a "$log"
  printf '%s\n' "$backup"
}

cleanup_backups() {
  local mode="${1:-prompt}"
  local log="${2:-/dev/null}"
  local config_dir="$HOME/.config"
  local dir backup latest
  local backups=()

  for dir in "$config_dir"/*; do
    [[ -d "$dir" ]] || continue
    backups=()
    for backup in "$dir"-backup-*; do
      [[ -d "$backup" ]] && backups+=("$backup")
    done
    ((${#backups[@]} > 1)) || continue

    latest="${backups[0]}"
    for backup in "${backups[@]}"; do
      [[ "$backup" -nt "$latest" ]] && latest="$backup"
    done

    if [[ "$mode" == auto ]]; then
      for backup in "${backups[@]}"; do
        [[ "$backup" == "$latest" ]] && continue
        rm -rf -- "$backup"
      done
      printf '%s\n' "${INFO:-[INFO]} Express mode: trimmed backups for ${dir##*/}, keeping ${latest##*/}." | tee -a "$log"
      continue
    fi

    printf '\n%s Found multiple backups for: %s\n' "${INFO:-[INFO]}" "${dir##*/}"
    printf '%s\n' "${YELLOW:-}Backups:${RESET:-}"
    for backup in "${backups[@]}"; do
      printf '  - %s\n' "${backup##*/}"
    done
    printf '%s' "${CAT:-[ACTION]} Delete older backups and keep only the latest? (y/N): "
    read -r back_choice
    if [[ "$back_choice" == [Yy]* ]]; then
      for backup in "${backups[@]}"; do
        [[ "$backup" == "$latest" ]] && continue
        rm -rf -- "$backup"
        printf 'Deleted: %s\n' "${backup##*/}"
      done
      printf 'Kept: %s\n' "${latest##*/}"
    fi
  done
}

# Transactional directory replacement.
# 1. Copy the candidate to a temporary sibling.
# 2. Rename the existing destination to a backup.
# 3. Rename the prepared candidate into place.
# If step 3 fails, restore the original destination.
replace_dir_transaction() {
  local source="$1"
  local destination="$2"
  local log="${3:-/dev/null}"
  local parent candidate backup

  [[ -d "$source" ]] || { printf 'missing source directory: %s\n' "$source" >&2; return 1; }
  parent="$(dirname "$destination")"
  mkdir -p -- "$parent"
  candidate="$(mktemp -d --tmpdir="$parent" '.dotfiles.XXXXXX')"
  backup=''

  if ! cp -a -- "$source/." "$candidate/" 2>&1 | tee -a "$log"; then
    rm -rf -- "$candidate"
    return 1
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    backup="${destination}-backup-$(get_backup_dirname)"
    if ! mv -- "$destination" "$backup" 2>&1 | tee -a "$log"; then
      rm -rf -- "$candidate"
      return 1
    fi
  fi

  if mv -- "$candidate" "$destination" 2>&1 | tee -a "$log"; then
    printf '%s\n' "$backup"
    return 0
  fi

  rm -rf -- "$candidate"
  if [[ -n "$backup" ]] && [[ ! -e "$destination" && ! -L "$destination" ]]; then
    mv -- "$backup" "$destination"
  fi
  return 1
}

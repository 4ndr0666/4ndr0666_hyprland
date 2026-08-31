#!/bin/bash
# User dotfile primitives. Prompting remains the caller's responsibility.

set -Eeuo pipefail

DOTFILES_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_CORE_DIR/files.sh"

dotfiles_replace() {
  local source="$1" destination="$2"

  [[ "$destination" == "$HOME"/* ]] || {
    printf '%s\n' "dotfile destination must remain under HOME: $destination" >&2
    return 1
  }

  mkdir -p -- "$(dirname "$destination")"
  file_state_atomic_replace "$source" "$destination"
}

dotfiles_restore() {
  file_state_restore_manifest
}

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COPY="$ROOT/copy.sh"

[[ -f "$COPY" ]] || { printf '[FAIL] Missing copy.sh\n' >&2; exit 1; }

grep -Eq '^#!/usr/bin/env bash$' "$COPY" || {
  printf '[FAIL] copy.sh does not use the canonical Bash entrypoint.\n' >&2
  exit 1
}

for helper in \
  scripts/copy_menu.sh \
  scripts/lib_backup.sh \
  scripts/lib_detect.sh \
  scripts/lib_prompts.sh \
  scripts/lib_apps.sh \
  scripts/lib_copy.sh \
  scripts/lib_update.sh; do
  grep -Fq "scripts/$(basename "$helper")" "$COPY" || {
    printf '[FAIL] copy.sh no longer references established helper boundary: %s\n' "$helper" >&2
    exit 1
  }
done

# copy.sh must not recreate the removed installer authority.
if grep -Eq 'assets/hyprland-install|scripts/install-hyprland' "$COPY"; then
  printf '[FAIL] copy.sh references removed legacy installer authority.\n' >&2
  exit 1
fi

printf '[PASS] copy.sh remains bounded by the established helper architecture and contains no legacy installer authority.\n'

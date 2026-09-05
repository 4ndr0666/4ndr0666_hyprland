#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COPY="$ROOT/copy.sh"

[[ -f "$COPY" ]] || { printf '[FAIL] Missing copy.sh\n' >&2; exit 1; }
grep -Eq '^#!/usr/bin/env bash$' "$COPY"
grep -q '^set -Eeuo pipefail$' "$COPY"

for helper in \
  scripts/copy_menu.sh \
  scripts/lib_backup.sh \
  scripts/lib_detect.sh \
  scripts/lib_prompts.sh \
  scripts/lib_apps.sh \
  scripts/lib_copy.sh; do
  grep -Fq "$helper" "$COPY" || {
    printf '[FAIL] Missing established helper boundary: %s\n' "$helper" >&2
    exit 1
  }
done

! grep -Eq 'enable_ags|DIRPATH_AGS|config/ags|command -v ags|/\.config/ags' "$COPY"
! grep -Eq 'run_repo_update|lib_update\.sh|git[[:space:]]+(stash|pull|fetch|merge|reset|checkout)' "$COPY"
! grep -Eq '(^|[[:space:]])wallust[[:space:]]+run([[:space:]]|$)' "$COPY"
grep -Fq 'WallustAwww.sh' "$COPY"

grep -q 'copy_phase1' "$COPY"
grep -q 'copy_waybar' "$COPY"
grep -q 'copy_phase2' "$COPY"
grep -q 'restore_hypr_assets' "$COPY"
grep -q 'restore_user_configs' "$COPY"
grep -q 'restore_user_scripts' "$COPY"
grep -q 'restore_hypr_files' "$COPY"
grep -q 'cleanup_backups' "$COPY"

printf '[PASS] copy.sh is a strict orchestration boundary with no AGS or self-update authority.\n'

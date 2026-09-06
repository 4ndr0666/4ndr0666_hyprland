#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COPY="$ROOT/copy.sh"
LIB_COPY="$ROOT/scripts/lib_copy.sh"
LIB_BACKUP="$ROOT/scripts/lib_backup.sh"

[[ -f "$COPY" ]] || { printf '[FAIL] Missing copy.sh\n' >&2; exit 1; }
[[ -f "$LIB_COPY" ]] || { printf '[FAIL] Missing lib_copy.sh\n' >&2; exit 1; }
[[ -f "$LIB_BACKUP" ]] || { printf '[FAIL] Missing lib_backup.sh\n' >&2; exit 1; }
grep -Eq '^#!/usr/bin/env bash$' "$COPY"
grep -q '^set -Eeuo pipefail$' "$COPY"
grep -q '^set -Eeuo pipefail$' "$LIB_COPY"
bash -n "$COPY"
bash -n "$LIB_COPY"
bash -n "$LIB_BACKUP"

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

grep -q 'detect_nvidia_adjust' "$COPY"
grep -q 'detect_vm_adjust' "$COPY"
grep -q 'detect_nixos_adjust' "$COPY"
grep -q 'prompt_resolution_choice' "$COPY"
grep -q 'prompt_clock_12h' "$COPY"

grep -q 'trap cleanup EXIT INT TERM HUP' "$COPY"

grep -Fq 'replace_dir_transaction "config/waybar" "$dir_path" "$log"' "$LIB_COPY"
grep -Fq 'replace_dir_transaction "$source" "$dir_path" "$log"' "$LIB_COPY"
grep -Fq 'LAST_HYPR_BACKUP_PATH="$backup_dir"' "$LIB_COPY"
! grep -Fq 'rm -rf "$DIRPATHw"' "$LIB_COPY"
! grep -Fq 'cp -r "$DIRPATHw" "$DIRPATHw-backup-' "$LIB_COPY"
! grep -Fq 'mv "$DIRPATH" "$DIRPATH-backup-' "$LIB_COPY"

printf '[PASS] copy and restore orchestration is strict and transaction-bounded.\n'

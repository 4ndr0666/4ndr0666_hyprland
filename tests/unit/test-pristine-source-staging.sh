#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COPY="$ROOT/copy.sh"
DETECT="$ROOT/scripts/lib_detect.sh"
APPS="$ROOT/scripts/lib_apps.sh"

[[ -f "$COPY" && -f "$DETECT" && -f "$APPS" ]]
bash -n "$COPY"

grep -Fq 'DEPLOY_STAGE_DIR=' "$COPY"
grep -Fq 'DEPLOY_STAGE_DIR="$(mktemp -d' "$COPY"
grep -Fq 'cp -a -- "$SOURCE_ROOT/config" "$DEPLOY_STAGE_DIR/"' "$COPY"
grep -Fq 'cp -a -- "$SOURCE_ROOT/wallpapers" "$DEPLOY_STAGE_DIR/"' "$COPY"
grep -Fq 'SCRIPT_DIR="$DEPLOY_STAGE_DIR"' "$COPY"
grep -Fq 'cd -- "$DEPLOY_STAGE_DIR"' "$COPY"
grep -Fq 'rm -rf -- "$DEPLOY_STAGE_DIR"' "$COPY"

grep -Fq 'detect_nvidia_adjust "$LOG"' "$COPY"
grep -Fq 'detect_vm_adjust "$LOG"' "$COPY"
grep -Fq 'detect_nixos_adjust "$LOG"' "$COPY"

grep -Fq 'sed -i' "$DETECT"
grep -Fq 'sed -i' "$APPS"

awk '
  /cd -- "\$DEPLOY_STAGE_DIR"/ { staged=1; next }
  /detect_nvidia_adjust "\$LOG"/ && staged { found=1 }
  END { exit(found ? 0 : 1) }
' "$COPY"

if grep -Eq 'rm -rf -- "\$SCRIPT_DIR/config"|rm -rf -- "\$SOURCE_ROOT/config"|rm -rf -- "\$SOURCE_ROOT/wallpapers"' "$COPY"; then
  printf '%s\n' '[FAIL] Staging cleanup may destroy the pristine source tree.' >&2
  exit 1
fi

printf '%s\n' '[PASS] pristine source staging contract'

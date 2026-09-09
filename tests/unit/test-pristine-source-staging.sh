#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COPY="$ROOT/copy.sh"
DETECT="$ROOT/scripts/lib_detect.sh"
APPS="$ROOT/scripts/lib_apps.sh"

[[ -f "$COPY" && -f "$DETECT" && -f "$APPS" ]]

grep -q 'DEPLOY_STAGE_DIR=' "$COPY"
grep -q 'mktemp -d' "$COPY"
grep -q 'cp -a -- "$SOURCE_ROOT/config"' "$COPY"
grep -q 'cp -a -- "$SOURCE_ROOT/wallpapers"' "$COPY"
grep -q 'cd -- "$DEPLOY_STAGE_DIR"' "$COPY"
grep -q 'trap cleanup EXIT INT TERM HUP' "$COPY"
grep -q 'SCRIPT_DIR="$DEPLOY_STAGE_DIR"' "$COPY"

detection_line="$(grep -n 'detect_nvidia_adjust' "$COPY" | head -n1 | cut -d: -f1)"
stage_line="$(grep -n 'cd -- "$DEPLOY_STAGE_DIR"' "$COPY" | head -n1 | cut -d: -f1)"
((detection_line > stage_line))

grep -Fq 'sed -i' "$DETECT"
grep -Fq 'sed -i' "$APPS"

if grep -Eq 'rm -rf -- "\$SCRIPT_DIR/config"|rm -rf -- "\$SOURCE_ROOT/config"' "$COPY"; then
  printf '%s\n' '[FAIL] Staging cleanup may destroy the pristine source tree.' >&2
  exit 1
fi

printf '%s\n' '[PASS] pristine source staging contract'

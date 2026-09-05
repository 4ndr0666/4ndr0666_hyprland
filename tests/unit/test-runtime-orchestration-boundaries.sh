#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for file in \
  "$ROOT/config/hypr/scripts/DarkLight.sh" \
  "$ROOT/config/hypr/scripts/Refresh.sh" \
  "$ROOT/config/hypr/scripts/KeyHints.sh" \
  "$ROOT/config/hypr/UserScripts/KeyHints.sh"; do
  [[ -f "$file" ]] || { printf '[FAIL] missing runtime script: %s\n' "$file" >&2; exit 1; }
  grep -q '^#!/usr/bin/env bash$' "$file"
  grep -q '^set -Eeuo pipefail$' "$file" || [[ "$file" == "$ROOT/config/hypr/scripts/KeyHints.sh" ]]
done

! grep -R -n --exclude-dir=.git --exclude-dir=archive 'ags\|/home/andro\|\.config/ags' \
  "$ROOT/config/hypr/scripts/DarkLight.sh" \
  "$ROOT/config/hypr/scripts/Refresh.sh" \
  "$ROOT/config/hypr/UserScripts/KeyHints.sh" >/dev/null 2>&1

! grep -Eq '(^|[[:space:]])eval[[:space:]]|xargs[[:space:]]+[^|]*sh' "$ROOT/config/hypr/scripts/DarkLight.sh" "$ROOT/config/hypr/UserScripts/KeyHints.sh"
grep -Fq 'WallustAwww.sh' "$ROOT/config/hypr/scripts/DarkLight.sh"
! grep -Fq 'wallust_rofi=' "$ROOT/config/hypr/scripts/DarkLight.sh"
! grep -Fq 'ags' "$ROOT/config/hypr/scripts/Refresh.sh"

grep -Fq 'exec "$SCRIPT_DIR/KeyHints.sh" "$@"' "$ROOT/config/hypr/UserScripts/KeyHints.sh"

printf '[PASS] runtime orchestration boundaries are strict and provider-consistent.\n'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/scripts/lib_copy.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ -f "$LIB" ]] || fail "copy helper is missing"

for path in "$ROOT/config/hypr/Monitor_Profiles" "$ROOT/config/hypr/UserConfigs"; do
  [[ -d "$path" ]] || fail "configuration capability source is missing: $path"
done

grep -Fq 'restore_hypr_assets()' "$LIB" || fail "monitor/profile restoration authority is missing"
grep -Fq 'for lua_dir in Monitor_Profiles animations' "$LIB" || fail "monitor profile restoration edge is missing"
grep -Fq 'restore_user_configs()' "$LIB" || fail "user configuration restoration authority is missing"
grep -Fq 'cleanup_duplicate_userconfigs' "$LIB" || fail "user configuration reconciliation edge is missing"
grep -Fq 'INSTALLED_VERSION_AT_START' "$ROOT/copy.sh" || fail "deployment transaction does not preserve installed-version state for user-config reconciliation"

printf 'PASS: monitor profiles and user configuration remain connected to deployment reconciliation\n'

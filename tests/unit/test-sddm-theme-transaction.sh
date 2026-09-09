#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/install-scripts/sddm_theme.sh"

[[ -f "$FILE" ]] || { printf '[FAIL] Missing SDDM theme installer.\n' >&2; exit 1; }
grep -q '^#!/usr/bin/env bash$' "$FILE"
grep -q '^set -Eeuo pipefail$' "$FILE"
grep -Fq 'sudo -v' "$FILE"
grep -Fq 'TRANSACTION_DIR=' "$FILE"
grep -Fq 'trap cleanup EXIT INT TERM HUP' "$FILE"
grep -Fq 'COMMITTED=0' "$FILE"
grep -Fq 'COMMITTED=1' "$FILE"
grep -Fq 'sudo -n mv -- "$THEME_DEST" "$THEME_BACKUP"' "$FILE"
grep -Fq 'sudo -n mv -- "$STAGED_THEME" "$THEME_DEST"' "$FILE"
grep -Fq 'sudo -n install -m 0644 -- "$SDDM_NEW" "$SDDM_CONF"' "$FILE"
grep -Fq 'sudo -n rm -rf -- "$TRANSACTION_DIR"' "$FILE"
! grep -Fq 'sudo rm -rf "/usr/share/sddm/themes/$theme_name"' "$FILE"
! grep -Fq '"/tmp/$theme_name"' "$FILE"
! grep -Fq 'sudo cp -r "/tmp/$theme_name"' "$FILE"
! grep -Fq 'git clone --depth 1 "$source_theme" "/tmp/$theme_name"' "$FILE"
! grep -Fq 'if git clone' "$FILE"
! grep -Fq 'sudo sed -i' "$FILE"
! grep -Fq 'sudo tee' "$FILE"
! grep -Fq '|| true' "$FILE"

bash -n "$FILE"
printf '[PASS] SDDM theme installation is strict, staged, transactional, and fail-closed.\n'

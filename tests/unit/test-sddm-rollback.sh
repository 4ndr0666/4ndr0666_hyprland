#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/install-scripts/sddm.sh"

# The systemd state capture happens before package installation, so package
# failure must restore it rather than deleting or abandoning the manifest.
grep -Fq 'systemd_capture_units "${LOGIN_MANAGER_UNITS[@]}"' "$SCRIPT"
grep -Fq 'restore_on_failure' "$SCRIPT"

after_capture="$(awk '/systemd_capture_units /, /printf.*Installing SDDM/' "$SCRIPT")"
grep -Fq 'restore_on_failure' <<<"$after_capture"
! grep -Fq 'rm -f -- "$SYSTEMD_STATE_MANIFEST"' "$SCRIPT"

# The ERR trap must cover the privileged transition, but package failure has an
# explicit rollback because commands used as the condition of `if !` are not
# reliably covered by ERR traps.
grep -Fq 'if ! package_install "${SDDM_PACKAGES[@]}"; then' "$SCRIPT"
grep -Fq '  restore_on_failure' "$SCRIPT"

echo 'sddm rollback invariant: PASS'

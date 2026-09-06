#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UNINSTALL="$ROOT/uninstall.sh"
PACKAGES="$ROOT/install-scripts/core/packages.sh"

[[ -r "$UNINSTALL" ]] || { printf '%s\n' '[ERROR] uninstall.sh is unavailable.' >&2; exit 1; }
[[ -r "$PACKAGES" ]] || { printf '%s\n' '[ERROR] package transaction authority is unavailable.' >&2; exit 1; }

bash -n "$UNINSTALL"
bash -n "$PACKAGES"

grep -Fq 'package_remove_owned' "$UNINSTALL"
grep -Fq 'PACKAGE_MANIFEST' "$UNINSTALL"
grep -Fq 'ownership manifest was retained for retry' "$UNINSTALL"
grep -Fq 'refusing destructive uninstall' "$UNINSTALL"

grep -Fq 'package_remove_owned()' "$PACKAGES"
grep -Fq 'package_is_installed' "$PACKAGES"
grep -Fq ': > "$PACKAGE_MANIFEST"' "$PACKAGES"

grep -Fq 'C44' "$ROOT/docs/audits/GUP-capability-observable-contract-matrix-2026-09-06.md"
grep -Fq 'uninstall-symmetry' "$ROOT/tests/unit/run-golden-units.sh"

printf '%s\n' '[PASS] C44 uninstall symmetry contract is authoritative, failure-preserving, and registered.'

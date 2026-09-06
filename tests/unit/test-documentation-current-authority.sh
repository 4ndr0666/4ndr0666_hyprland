#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
README="$ROOT_DIR/README.md"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -f "$README" ]] || fail "README is missing"
grep -Fq '(`./copy.sh`)' "$README" || fail "README no longer identifies copy.sh as the deployment authority"
grep -Fq '(`./uninstall.sh`)' "$README" || fail "README no longer identifies uninstall.sh as the uninstall authority"
! grep -Fq '(`./release.sh`)' "$README" || fail "README references removed release.sh entrypoint"
! grep -Fq '(`./upgrade.sh`)' "$README" || fail "README references removed upgrade.sh entrypoint"

printf 'PASS: documentation names only current deployment entrypoints\n'

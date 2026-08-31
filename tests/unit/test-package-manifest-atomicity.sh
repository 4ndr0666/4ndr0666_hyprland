#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/install-scripts/core/packages.sh"

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT

export PACKAGE_MANIFEST="$TMP/packages.manifest"
export LOG="$TMP/packages.log"
package_core_init

package_manifest_record alpha beta gamma
[[ "$(cat "$PACKAGE_MANIFEST")" == $'alpha\nbeta\ngamma' ]]
package_manifest_record alpha
[[ "$(wc -l < "$PACKAGE_MANIFEST")" -eq 3 ]]

echo 'package manifest atomicity: PASS'

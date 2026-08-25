#!/usr/bin/env bash
# Golden Unit: the bootstrap's immutable installer ref must match release.ref.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE_REF_FILE="$ROOT/release.ref"
BOOTSTRAP="$ROOT/auto-install.sh"

ref="$(tr -d '[:space:]' < "$RELEASE_REF_FILE")"
[[ "$ref" =~ ^[0-9a-fA-F]{40}$ ]] || {
  printf '[FAIL] release.ref is not exactly one 40-character commit SHA.\n' >&2
  exit 1
}

grep -Fq "RELEASE_REF=\"$ref\"" "$BOOTSTRAP" || {
  printf '[FAIL] auto-install.sh RELEASE_REF diverges from release.ref.\n' >&2
  exit 1
}

printf '[PASS] bootstrap RELEASE_REF matches release.ref.\n'

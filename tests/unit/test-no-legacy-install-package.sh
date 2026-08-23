#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if grep -RInE '(^|[^[:alnum:]_])install_package[[:space:]]*\(' \
  "$ROOT/install-scripts" --include='*.sh' >/dev/null 2>&1; then
  echo 'legacy install_package API reference detected' >&2
  exit 1
fi

echo 'legacy install_package API invariant: PASS'

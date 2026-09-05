#!/usr/bin/env bash
# === 4ndr0666 === #
# Compatibility entry point for the canonical KeyHints implementation.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
exec "$SCRIPT_DIR/KeyHints.sh" "$@"

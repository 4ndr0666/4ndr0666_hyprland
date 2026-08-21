#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/Distro-Hyprland.sh"

assert_refused() {
  local output rc
  set +e
  output=$(env -u HYPRLAND_INSTALL_REF TERM=dumb bash "$SCRIPT" 2>&1)
  rc=$?
  set -e

  ((rc == 2)) || {
    printf '%s\n' "expected bootstrap to reject missing revision, got rc=$rc" >&2
    printf '%s\n' "$output" >&2
    exit 1
  }
  grep -Fq 'HYPRLAND_INSTALL_REF must be a full 40-character commit ID' <<<"$output"
}

assert_invalid_ref_refused() {
  local output rc
  set +e
  output=$(HYPRLAND_INSTALL_REF=main TERM=dumb bash "$SCRIPT" 2>&1)
  rc=$?
  set -e

  ((rc == 2)) || {
    printf '%s\n' "expected bootstrap to reject mutable ref, got rc=$rc" >&2
    printf '%s\n' "$output" >&2
    exit 1
  }
  grep -Fq 'Refusing to execute mutable branch/tag content' <<<"$output"
}

assert_refused
assert_invalid_ref_refused
printf '%s\n' 'bootstrap: PASS'

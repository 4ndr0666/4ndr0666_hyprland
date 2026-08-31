#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/Distro-Hyprland.sh"

assert_missing_release_ref_refused() {
  local tmp output rc
  tmp="$(mktemp -d)"
  trap 'rm -rf -- "$tmp"' RETURN
  cp -- "$SCRIPT" "$tmp/Distro-Hyprland.sh"

  set +e
  output=$(env -u HYPRLAND_INSTALL_REF TERM=dumb bash "$tmp/Distro-Hyprland.sh" 2>&1)
  rc=$?
  set -e

  ((rc == 2)) || {
    printf '%s\n' "expected bootstrap to reject missing release revision, got rc=$rc" >&2
    printf '%s\n' "$output" >&2
    exit 1
  }
  grep -Fq 'No release revision is configured' <<<"$output"
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
  grep -Fq 'Mutable branches and tags are not accepted' <<<"$output"
}

assert_missing_release_ref_refused
assert_invalid_ref_refused
printf '%s\n' 'bootstrap: PASS'

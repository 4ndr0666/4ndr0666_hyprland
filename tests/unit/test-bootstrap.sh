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

assert_bootstrap_transaction_invariants() {
  grep -q '^set -Eeuo pipefail$' "$SCRIPT"
  grep -q '^GIT_COMMAND_TIMEOUT=' "$SCRIPT"
  grep -q '^INSTALL_DIR_CREATED=0$' "$SCRIPT"
  grep -q '^trap cleanup EXIT INT TERM HUP$' "$SCRIPT"
  grep -Fq 'timeout --signal=TERM --kill-after=30s' "$SCRIPT"
  grep -Fq 'git clone --no-checkout "$REPOSITORY_URL" "$INSTALL_DIR"' "$SCRIPT"
  grep -Fq 'git fetch --depth=1 origin "$INSTALL_REF"' "$SCRIPT"
  grep -Fq 'git checkout --detach --force "$INSTALL_REF"' "$SCRIPT"
  grep -Fq 'INSTALL_DIR_CREATED=1' "$SCRIPT"
  grep -Fq 'INSTALL_DIR_CREATED=0' "$SCRIPT"
  ! grep -Fq 'git clone --no-checkout "$REPOSITORY_URL" "$INSTALL_DIR" || true' "$SCRIPT"
  bash -n "$SCRIPT"
}

assert_missing_release_ref_refused
assert_invalid_ref_refused
assert_bootstrap_transaction_invariants
printf '%s\n' 'bootstrap: PASS'

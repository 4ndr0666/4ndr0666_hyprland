#!/usr/bin/env bash
set -Eeuo pipefail

oma2_recovery() {
  local failures=0
  local workdir target before after backup
  workdir="$(mktemp -d)"
  target="$workdir/state"
  backup="$workdir/state.backup"
  before='known-good-prestate'
  after='known-good-poststate'

  printf '%s\n' "$before" > "$target"
  cp -- "$target" "$backup"

  oma2_section recovery
  oma2_probe prestate_created grep -Fxq "$before" "$target" || failures=$((failures + 1))

  if cp -- "$target" "$workdir/staged" && printf '%s\n' "$after" > "$workdir/staged"; then
    mv -- "$workdir/staged" "$target"
  else
    failures=$((failures + 1))
  fi
  oma2_probe committed_state grep -Fxq "$after" "$target" || failures=$((failures + 1))

  cp -- "$backup" "$target"
  oma2_probe rollback_restores_prestate grep -Fxq "$before" "$target" || failures=$((failures + 1))
  oma2_probe no_staged_artifact test ! -e "$workdir/staged" || failures=$((failures + 1))

  rm -rf "$workdir"
  return "$failures"
}

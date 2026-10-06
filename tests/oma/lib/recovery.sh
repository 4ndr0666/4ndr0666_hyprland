#!/usr/bin/env bash
set -Eeuo pipefail

oma2_recovery() {
  (
    local failures=0
    local workdir target before after backup staged
    workdir="$(mktemp -d)"
    trap 'rm -rf -- "$workdir"' EXIT
    target="$workdir/state"
    backup="$workdir/state.backup"
    staged="$workdir/staged"
    before='known-good-prestate'
    after='known-good-poststate'

    printf '%s\n' "$before" > "$target"
    cp -- "$target" "$backup"

    oma2_section recovery
    oma2_probe prestate_created grep -Fxq "$before" "$target" || failures=$((failures + 1))

    printf '%s\n' "$after" > "$staged"
    if mv -- "$workdir/missing" "$target" 2>"$OMA2_TMP"; then
      failures=$((failures + 1))
    fi
    oma2_probe injected_failure_preserves_prestate grep -Fxq "$before" "$target" || failures=$((failures + 1))
    oma2_probe staged_state_is_not_committed test -e "$staged" || failures=$((failures + 1))

    mv -- "$staged" "$target"
    oma2_probe committed_state grep -Fxq "$after" "$target" || failures=$((failures + 1))

    cp -- "$backup" "$target"
    oma2_probe rollback_restores_prestate grep -Fxq "$before" "$target" || failures=$((failures + 1))
    oma2_probe no_staged_artifact test ! -e "$staged" || failures=$((failures + 1))

    return "$failures"
  )
}

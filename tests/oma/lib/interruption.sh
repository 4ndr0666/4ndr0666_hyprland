#!/usr/bin/env bash
set -Eeuo pipefail

oma2_interruption() {
  (
    local failures=0
    local workdir target marker child
    workdir="$(mktemp -d)"
    trap 'rm -rf -- "$workdir"' EXIT
    target="$workdir/state"
    marker="$workdir/commit.marker"
    printf '%s\n' 'pre-state' > "$target"

    oma2_section interruption

    (
      tmp="$target.tmp"
      printf '%s\n' 'post-state' > "$tmp"
      printf '%s\n' 'staged' > "$marker"
      kill -TERM "$BASHPID"
    ) &
    child=$!
    wait "$child" 2>/dev/null || true

    oma2_probe interrupted_commit_keeps_valid_prestate grep -Fxq 'pre-state' "$target" || failures=$((failures + 1))
    oma2_probe interrupted_commit_has_no_committed_marker test ! -e "$workdir/commit.complete" || failures=$((failures + 1))
    rm -f -- "$target.tmp" "$marker"
    oma2_probe interruption_cleanup test ! -e "$target.tmp" || failures=$((failures + 1))

    return "$failures"
  )
}

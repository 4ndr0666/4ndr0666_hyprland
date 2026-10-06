#!/usr/bin/env bash
set -Eeuo pipefail

oma2_concurrency() {
  (
    local failures=0
    local workdir lockfile counter
    workdir="$(mktemp -d)"
    trap 'rm -rf -- "$workdir"' EXIT

    lockfile="$workdir/commit.lock"
    counter="$workdir/counter"
    printf '0\n' > "$counter"

    oma2_section concurrency

    (
      flock -x 9
      value="$(cat "$counter")"
      sleep 0.2
      printf '%s\n' "$((value + 1))" > "$counter"
    ) 9>"$lockfile" &
    local pid1=$!

    (
      flock -x 9
      value="$(cat "$counter")"
      printf '%s\n' "$((value + 1))" > "$counter"
    ) 9>"$lockfile" &
    local pid2=$!

    wait "$pid1" || failures=$((failures + 1))
    wait "$pid2" || failures=$((failures + 1))

    oma2_probe serialized_updates bash -c '[[ "$(cat "$1")" == 2 ]]' _ "$counter" || failures=$((failures + 1))
    oma2_probe lockfile_not_corrupted test -f "$lockfile" || failures=$((failures + 1))

    return "$failures"
  )
}

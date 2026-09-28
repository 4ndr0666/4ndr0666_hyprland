#!/usr/bin/env bash
set -Eeuo pipefail

oma2_concurrency() {
  local failures=0
  local workdir lockfile result1 result2
  workdir="$(mktemp -d)"
  lockfile="$workdir/commit.lock"
  result1="$workdir/result.1"
  result2="$workdir/result.2"

  oma2_section concurrency

  (
    flock -x 9
    sleep 0.2
    printf 'worker-1\n' > "$result1"
  ) 9>"$lockfile" &
  local pid1=$!

  (
    flock -x 9
    printf 'worker-2\n' > "$result2"
  ) 9>"$lockfile" &
  local pid2=$!

  wait "$pid1" || failures=$((failures + 1))
  wait "$pid2" || failures=$((failures + 1))

  oma2_probe serialized_workers bash -c '[[ -s "$1" && -s "$2" ]]' _ "$result1" "$result2" || failures=$((failures + 1))
  oma2_probe lockfile_not_corrupted bash -c '[[ -f "$1" && "$(wc -l < "$1")" -eq 0 ]]' _ "$lockfile" || failures=$((failures + 1))

  rm -rf "$workdir"
  return "$failures"
}

#!/usr/bin/env bash
# Repository self-update is intentionally disabled.
#
# The installer bootstrap is revision-pinned. In-place git stash/pull operations
# would reintroduce mutable remote execution into an already running installer.
# Obtain a reviewed release.ref and rerun the immutable bootstrap instead.

run_repo_update() {
  printf '%s\n' '[ERROR] In-place repository updates are disabled.' >&2
  printf '%s\n' '[ERROR] Re-run the immutable bootstrap with a reviewed release.ref.' >&2
  return 1
}

#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd -- "$PARENT_DIR"

LOG="Install-Logs/install-$(date +%d-%H%M%S)_themes.log"
mkdir -p -- "$(dirname -- "$LOG")"
source "$SCRIPT_DIR/core/packages.sh"

readonly GTK_REPOSITORY_URL="https://github.com/JaKooLit/GTK-themes-icons.git"
readonly GTK_REPOSITORY_REVISION="1ee8d6bbe9745fd4be580a7621e2d611b00f4967"
readonly GIT_COMMAND_TIMEOUT="${GIT_COMMAND_TIMEOUT:-900}"
GTK_STAGE_DIR=""

cleanup() {
  local rc=$?
  if [[ -n "$GTK_STAGE_DIR" && -d "$GTK_STAGE_DIR" ]]; then
    rm -rf -- "$GTK_STAGE_DIR"
  fi
  return "$rc"
}
trap cleanup EXIT INT TERM HUP

if [[ ! "$GIT_COMMAND_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  printf '%s\n' '[ERROR] GIT_COMMAND_TIMEOUT must be a positive integer number of seconds.' >&2
  exit 2
fi
command -v timeout >/dev/null 2>&1 || {
  printf '%s\n' '[ERROR] timeout is required for GTK theme installation.' >&2
  exit 1
}

engine=(
  unzip
  gtk-engine-murrine
)
package_install "${engine[@]}"

GTK_STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-gtk-themes.XXXXXX")"
GTK_REPOSITORY_DIR="$GTK_STAGE_DIR/GTK-themes-icons"

printf '%s\n' '[NOTE] Staging pinned GTK themes and icons repository...' | tee -a "$LOG"
timeout --signal=TERM --kill-after=30s "${GIT_COMMAND_TIMEOUT}s" \
  git clone --quiet --filter=blob:none --no-checkout "$GTK_REPOSITORY_URL" "$GTK_REPOSITORY_DIR" 2>>"$LOG"
timeout --signal=TERM --kill-after=30s "${GIT_COMMAND_TIMEOUT}s" \
  git -C "$GTK_REPOSITORY_DIR" checkout --quiet --detach "$GTK_REPOSITORY_REVISION" 2>>"$LOG"
actual_revision="$(git -C "$GTK_REPOSITORY_DIR" rev-parse HEAD)"
[[ "$actual_revision" == "$GTK_REPOSITORY_REVISION" ]] || {
  printf '%s\n' '[ERROR] GTK theme repository revision verification failed.' >&2
  exit 1
}
[[ -x "$GTK_REPOSITORY_DIR/auto-extract.sh" ]] || {
  printf '%s\n' '[ERROR] GTK theme repository is missing executable auto-extract.sh.' >&2
  exit 1
}

printf '%s\n' '[NOTE] Extracting GTK Themes & Icons...' | tee -a "$LOG"
(
  cd -- "$GTK_REPOSITORY_DIR"
  ./auto-extract.sh
) 2>&1 | tee -a "$LOG"

printf '%s\n' '[OK] Extracted GTK Themes & Icons to ~/.icons & ~/.themes directories' | tee -a "$LOG"

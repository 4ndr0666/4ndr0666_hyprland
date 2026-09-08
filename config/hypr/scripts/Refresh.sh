#!/usr/bin/env bash
# === 4ndr0666 === #
# Refresh Waybar, Rofi, SwayNC, and the supported Quickshell session.
set -Eeuo pipefail

SCRIPTSDIR="$HOME/.config/hypr/scripts"
USER_SCRIPTS="$HOME/.config/hypr/UserScripts"

started_pids=()
restore_components=()

cleanup_started() {
  local cleanup_status=0
  local pid
  for pid in "${started_pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      if kill "$pid" 2>/dev/null; then
        :
      else
        local rc=$?
        ((rc == 1)) || cleanup_status=$rc
      fi
    fi
  done
  started_pids=()
  return "$cleanup_status"
}

start_component() {
  local label="$1"
  shift
  "$@" >/dev/null 2>&1 &
  local pid=$!
  started_pids+=("$pid")

  if kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  local rc=0
  wait "$pid" || rc=$?
  printf '%s\n' "Refresh lifecycle failure: $label exited during startup with status $rc" >&2
  return 1
}

start_optional_component() {
  local label="$1"
  shift
  "$@" >/dev/null 2>&1 &
  local pid=$!
  started_pids+=("$pid")

  if kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  local rc=0
  wait "$pid" || rc=$?
  if ((rc == 127)); then
    unset 'started_pids[-1]'
    return 0
  fi

  printf '%s\n' "Refresh lifecycle failure: $label exited during startup with status $rc" >&2
  return 1
}

record_component_state() {
  local process="$1"
  if pgrep -x -- "$process" >/dev/null 2>&1; then
    restore_components+=("$process")
  else
    local rc=$?
    ((rc == 1)) || return "$rc"
  fi
}

stop_component() {
  local process="$1"
  if pkill -- "$process" >/dev/null 2>&1; then
    return 0
  fi
  local rc=$?
  ((rc == 1)) || return "$rc"
}

restore_component_state() {
  local rollback_status=0
  local process
  for process in "${restore_components[@]}"; do
    if start_component "rollback-$process" "$process"; then
      unset 'started_pids[-1]'
    else
      local rc=$?
      ((rollback_status == 0)) && rollback_status=$rc
    fi
  done
  restore_components=()
  return "$rollback_status"
}

cleanup() {
  local rc=$?
  if ((rc != 0)); then
    local cleanup_rc=0
    cleanup_started || cleanup_rc=$?
    local rollback_rc=0
    restore_component_state || rollback_rc=$?
    local rollback_cleanup_rc=0
    cleanup_started || rollback_cleanup_rc=$?
    if ((cleanup_rc != 0)); then
      printf '%s\n' "Refresh lifecycle cleanup failed with status $cleanup_rc" >&2
      rc=$cleanup_rc
    fi
    if ((rollback_rc != 0)); then
      printf '%s\n' "Refresh lifecycle rollback failed with status $rollback_rc" >&2
      rc=$rollback_rc
    fi
    if ((rollback_cleanup_rc != 0)); then
      printf '%s\n' "Refresh lifecycle rollback cleanup failed with status $rollback_cleanup_rc" >&2
      rc=$rollback_cleanup_rc
    fi
  else
    started_pids=()
    restore_components=()
  fi
  return "$rc"
}
trap cleanup EXIT

record_component_state waybar
record_component_state rofi
record_component_state swaync
record_component_state swaybg
record_component_state qs

stop_component waybar
stop_component rofi
stop_component swaync
stop_component swaybg
stop_component qs

# Preserve the existing Waybar refresh signal, but classify only its documented
# no-process status as benign.
if pkill -SIGUSR2 waybar >/dev/null 2>&1; then
  :
else
  rc=$?
  ((rc == 1)) || { printf '%s\n' "Refresh lifecycle failure: Waybar refresh signal failed with status $rc" >&2; exit "$rc"; }
fi

# Quickshell owns the desktop shell lifecycle. Its absence remains optional;
# an installed shell that exits during startup is authoritative failure.
start_optional_component Quickshell qs

start_component waybar waybar
start_component swaync swaync
swaync-client --reload-config

if [[ -x "$USER_SCRIPTS/RainbowBorders.sh" ]]; then
  start_component RainbowBorders "$USER_SCRIPTS/RainbowBorders.sh"
fi

# All replacement processes survived their startup boundary; ownership now
# transfers to the desktop session and EXIT cleanup must not terminate them.
started_pids=()
restore_components=()
exit 0

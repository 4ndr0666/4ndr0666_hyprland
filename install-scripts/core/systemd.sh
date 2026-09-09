#!/bin/bash
# === 4ndr0666 === #
# Small systemd state primitives for service transitions.
# This file deliberately does not implement a generic rollback framework.

SYSTEMD_STATE_DEFAULT="${XDG_STATE_HOME:-$HOME/.local/state}/4ndr0666-hyprland/systemd.manifest"

systemd_core_init() {
  : "${SYSTEMD_STATE_MANIFEST:=$SYSTEMD_STATE_DEFAULT}"
  mkdir -p "$(dirname "$SYSTEMD_STATE_MANIFEST")"
  touch "$SYSTEMD_STATE_MANIFEST"
}

systemd_unit_exists() {
  local state
  state="$(systemctl show -p LoadState --value -- "$1")" || return $?
  case "$state" in
    loaded|masked|merged|stub) return 0 ;;
    not-found) return 1 ;;
    *)
      printf '%s\n' "[ERROR] Unexpected systemd LoadState for $1: ${state:-<empty>}" >&2
      return 2
      ;;
  esac
}

systemd_unit_enabled_state() {
  local state rc
  if state="$(systemctl is-enabled -- "$1")"; then
    rc=0
  else
    rc=$?
  fi
  case "$state" in
    enabled|disabled|static|indirect|generated|transient|masked|linked|linked-runtime)
      printf '%s\n' "$state"
      return 0
      ;;
    *)
      printf '%s\n' "[ERROR] systemctl is-enabled failed for $1 (rc=$rc): ${state:-<empty>}" >&2
      return "${rc:-2}"
      ;;
  esac
}

systemd_unit_active_state() {
  local state rc
  if state="$(systemctl is-active -- "$1")"; then
    rc=0
  else
    rc=$?
  fi
  case "$state" in
    active|inactive|failed|activating|deactivating)
      printf '%s\n' "$state"
      return 0
      ;;
    *)
      printf '%s\n' "[ERROR] systemctl is-active failed for $1 (rc=$rc): ${state:-<empty>}" >&2
      return "${rc:-2}"
      ;;
  esac
}

systemd_record_unit() {
  local unit="$1"
  local enabled active rc

  if systemd_unit_exists "$unit"; then
    :
  else
    rc=$?
    ((rc == 1)) || return "$rc"
    printf '%s|absent|absent\n' "$unit" >> "$SYSTEMD_STATE_MANIFEST"
    return 0
  fi

  enabled="$(systemd_unit_enabled_state "$unit")" || return $?
  active="$(systemd_unit_active_state "$unit")" || return $?
  printf '%s|%s|%s\n' "$unit" "$enabled" "$active" >> "$SYSTEMD_STATE_MANIFEST"
}

systemd_capture_units() {
  local unit

  systemd_core_init
  : > "$SYSTEMD_STATE_MANIFEST"
  for unit in "$@"; do
    systemd_record_unit "$unit"
  done
}

systemd_restore_units() {
  local unit enabled active current_enabled current_active

  [[ -s "$SYSTEMD_STATE_MANIFEST" ]] || return 0

  while IFS='|' read -r unit enabled active; do
    [[ -n "$unit" ]] || continue

    if [[ "$enabled" == absent ]]; then
      if systemd_unit_exists "$unit"; then
        current_enabled="$(systemd_unit_enabled_state "$unit")" || return $?
        current_active="$(systemd_unit_active_state "$unit")" || return $?
        [[ "$current_enabled" == disabled || "$current_enabled" == static || "$current_enabled" == absent ]] || sudo systemctl disable -- "$unit" >/dev/null
        [[ "$current_active" == inactive || "$current_active" == absent ]] || sudo systemctl stop -- "$unit" >/dev/null
      fi
      continue
    fi

    case "$enabled" in
      enabled|linked|linked-runtime) sudo systemctl enable -- "$unit" >/dev/null ;;
      disabled) sudo systemctl disable -- "$unit" >/dev/null ;;
      masked) sudo systemctl mask -- "$unit" >/dev/null ;;
      static|indirect|generated|transient) ;;
      *) return 1 ;;
    esac

    case "$active" in
      active) sudo systemctl start -- "$unit" >/dev/null ;;
      inactive|failed) sudo systemctl stop -- "$unit" >/dev/null ;;
      activating|deactivating) ;;
      *) return 1 ;;
    esac
  done < "$SYSTEMD_STATE_MANIFEST"
}

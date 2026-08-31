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
  [[ "$(systemctl show -p LoadState --value -- "$1" 2>/dev/null)" == loaded ]]
}

systemd_unit_enabled_state() {
  local state
  state="$(systemctl is-enabled -- "$1" 2>/dev/null || true)"
  case "$state" in
    enabled|disabled|static|indirect|generated|transient|masked|linked|linked-runtime)
      printf '%s\n' "$state"
      ;;
    *)
      printf '%s\n' absent
      ;;
  esac
}

systemd_unit_active_state() {
  local state
  state="$(systemctl is-active -- "$1" 2>/dev/null || true)"
  case "$state" in
    active|inactive|failed|activating|deactivating)
      printf '%s\n' "$state"
      ;;
    *)
      printf '%s\n' absent
      ;;
  esac
}

systemd_record_unit() {
  local unit="$1"
  local enabled active

  if ! systemd_unit_exists "$unit"; then
    printf '%s|absent|absent\n' "$unit" >> "$SYSTEMD_STATE_MANIFEST"
    return 0
  fi

  enabled="$(systemd_unit_enabled_state "$unit")"
  active="$(systemd_unit_active_state "$unit")"
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
        current_enabled="$(systemd_unit_enabled_state "$unit")"
        current_active="$(systemd_unit_active_state "$unit")"
        [[ "$current_enabled" == disabled || "$current_enabled" == static || "$current_enabled" == absent ]] || sudo systemctl disable -- "$unit" >/dev/null
        [[ "$current_active" == inactive || "$current_active" == absent ]] || sudo systemctl stop -- "$unit" >/dev/null
      fi
      continue
    fi

    case "$enabled" in
      enabled|linked|linked-runtime)
        sudo systemctl enable -- "$unit" >/dev/null
        ;;
      disabled)
        sudo systemctl disable -- "$unit" >/dev/null
        ;;
      masked)
        sudo systemctl mask -- "$unit" >/dev/null
        ;;
      static|indirect|generated|transient)
        ;;
      *)
        return 1
        ;;
    esac

    case "$active" in
      active)
        sudo systemctl start -- "$unit" >/dev/null
        ;;
      inactive|failed)
        sudo systemctl stop -- "$unit" >/dev/null
        ;;
      activating|deactivating)
        ;;
      *)
        return 1
        ;;
    esac
  done < "$SYSTEMD_STATE_MANIFEST"
}

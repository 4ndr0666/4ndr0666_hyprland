#!/usr/bin/env bash
set -Eeuo pipefail

oma2_lifecycle_safe() {
  local failures=0

  oma2_section lifecycle
  oma2_probe user_manager_running bash -c '[[ "$(systemctl --user is-system-running 2>/dev/null || true)" == running ]]' || failures=$((failures + 1))
  oma2_probe dbus_user_bus busctl --user list || failures=$((failures + 1))

  local units=(swaync.service waybar.service pipewire.service wireplumber.service hypridle.service)
  for unit in "${units[@]}"; do
    if systemctl --user cat "$unit" >"$OMA2_TMP" 2>&1; then
      oma2_emit "unit_${unit//[^[:alnum:]]/_}=PRESENT"
      if systemctl --user is-active --quiet "$unit"; then
        oma2_emit "active_${unit//[^[:alnum:]]/_}=yes"
      else
        oma2_emit "active_${unit//[^[:alnum:]]/_}=no"
      fi
    else
      oma2_emit "unit_${unit//[^[:alnum:]]/_}=ABSENT"
    fi
  done

  oma2_probe no_orphan_swaync bash -c 'pids="$(pidof swaync 2>/dev/null || true)"; [[ -z "$pids" || "$(wc -w <<<"$pids")" -eq 1 ]]' || failures=$((failures + 1))
  oma2_probe no_orphan_waybar bash -c 'pids="$(pidof waybar 2>/dev/null || true)"; [[ -z "$pids" || "$(wc -w <<<"$pids")" -eq 1 ]]' || failures=$((failures + 1))

  return "$failures"
}

oma2_lifecycle_destructive() {
  : "${OMA2_DESTRUCTIVE:?set OMA2_DESTRUCTIVE=1 on a disposable certification host}"
  local failures=0
  local units=(swaync.service waybar.service hypridle.service)

  oma2_section lifecycle-destructive
  for unit in "${units[@]}"; do
    if ! systemctl --user cat "$unit" >/dev/null 2>&1; then
      oma2_emit "${unit}=SKIP(absent)"
      continue
    fi
    oma2_probe "${unit}_restart" systemctl --user restart "$unit" || failures=$((failures + 1))
    oma2_probe "${unit}_active" systemctl --user is-active --quiet "$unit" || failures=$((failures + 1))
  done
  return "$failures"
}

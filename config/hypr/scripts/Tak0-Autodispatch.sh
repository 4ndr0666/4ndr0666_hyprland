#!/usr/bin/env bash

# ─────────────────────────────────────────────────────────────────────────────
# Tak0-Autodispatch.sh
# ─────────────────────────────────────────────────────────────────────────────
# Authoritative spawn dispatcher for Hyprland. Temporary capture rules are
# installed before launch, process lineage is supervised, and cleanup removes
# all temporary rules on every exit path.
# ─────────────────────────────────────────────────────────────────────────────

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$SCRIPT_DIR/dispatch.log"

fail() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM

  printf 'Cleanup: removing temporary capture rules and initialWorkspace at %s\n' "$(date)" >>"$LOGFILE"
  if ! hyprctl keyword windowrulev2 "unset, initialClass:.*" >>"$LOGFILE" 2>&1; then
    printf '[ERROR] failed to remove global temporary capture rule\n' >&2
    ((status == 0)) && status=1
  fi
  for RULE in "${CAPTURE_RULES[@]}"; do
    printf 'Cleanup: removing temporary capture rule: %s\n' "$RULE" >>"$LOGFILE"
    if ! hyprctl keyword windowrulev2 "unset, $RULE" >>"$LOGFILE" 2>&1; then
      printf '[ERROR] failed to remove temporary capture rule: %s\n' "$RULE" >&2
      ((status == 0)) && status=1
    fi
  done
  exit "$status"
}

TARGET_WS="${1-}"
[[ -n "$TARGET_WS" ]] || fail "missing target workspace"
shift

CAPTURE_RULES=()
while [[ "${1-}" != "--" && -n "${1-}" ]]; do
  CAPTURE_RULES+=("$1")
  shift
done

[[ "${1-}" == "--" ]] || fail "missing -- command separator"
shift
(($#)) || fail "missing command after --"

CMD=("$@")
printf "=== Deploy '%q' → WS %s @ %s ===\n" "${CMD[*]}" "$TARGET_WS" "$(date)" >>"$LOGFILE"

# Hyprland may not be ready during early autostart. Fail loudly if it never
# becomes queryable rather than launching with an ineffective capture rule.
ready=0
for _ in {1..50}; do
  if hyprctl -j monitors >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 0.1
done
((ready)) || fail "Hyprland did not become ready within 5 seconds"

trap cleanup EXIT INT TERM

printf 'Applying temporary initialWorkspace capture (initialClass:.*)\n' >>"$LOGFILE"
hyprctl keyword windowrulev2 \
  "initialWorkspace $TARGET_WS silent, initialClass:.*" \
  >>"$LOGFILE" 2>&1

for RULE in "${CAPTURE_RULES[@]}"; do
  printf 'Applying temporary capture rule: %s\n' "$RULE" >>"$LOGFILE"
  hyprctl keyword windowrulev2 \
    "initialWorkspace $TARGET_WS silent, $RULE" \
    >>"$LOGFILE" 2>&1
done

# Launch verbatim without an extra shell parsing pass.
"${CMD[@]}" &
ROOT_PID=$!
printf 'Root PID: %s\n' "$ROOT_PID" >>"$LOGFILE"

APP_NAME=""
for _ in {1..20}; do
  if [[ -r "/proc/$ROOT_PID/comm" ]]; then
    APP_NAME="$(tr -d '\0' </proc/$ROOT_PID/comm)"
    break
  fi
  sleep 0.05
done

if [[ -z "$APP_NAME" ]]; then
  APP_NAME="$(basename -- "${CMD[0]}")"
fi
printf 'App gate name: %s\n' "$APP_NAME" >>"$LOGFILE"

sleep 1.5

printf 'Releasing ultra-early wide capture\n' >>"$LOGFILE"
hyprctl keyword windowrulev2 "unset, initialClass:.*" >>"$LOGFILE" 2>&1

get_descendants() {
  local root="$1"
  local all=("$root")
  local changed=1

  while ((changed)); do
    changed=0
    for p in "${all[@]}"; do
      while read -r c; do
        [[ -n "$c" ]] || continue
        if [[ ! " ${all[*]} " =~ " $c " ]]; then
          all+=("$c")
          changed=1
        fi
      done < <(pgrep -P "$p" 2>/dev/null || true)
    done
  done

  printf '%s\n' "${all[*]}"
}

pid_matches_app() {
  local pid="$1"
  local comm
  comm="$(ps -p "$pid" -o comm= 2>/dev/null)" || return 1
  [[ "$comm" == "$APP_NAME" || "$comm" == "$APP_NAME"* ]]
}

END_TIME=$((SECONDS + 20))
declare -A SEEN=()

while ((SECONDS < END_TIME)); do
  PIDS="$(get_descendants "$ROOT_PID")"

  while IFS=$'\t' read -r PID ADDR CLASS; do
    [[ -n "$PID" && -n "$ADDR" ]] || continue
    MATCH=0

    for TPID in $PIDS; do
      [[ "$PID" == "$TPID" ]] && MATCH=1 && break
    done

    pid_matches_app "$PID" && MATCH=1

    for RULE in "${CAPTURE_RULES[@]}"; do
      if [[ "$RULE" =~ class:\^\((.*)\)\$ ]]; then
        [[ "$CLASS" =~ ${BASH_REMATCH[1]} ]] && MATCH=1
      fi
    done

    if ((MATCH)) && [[ -z "${SEEN[$ADDR]-}" ]]; then
      printf 'Placing window %s (pid %s, class %s) → WS %s\n' "$ADDR" "$PID" "$CLASS" "$TARGET_WS" >>"$LOGFILE"
      hyprctl dispatch movetoworkspacesilent \
        "$TARGET_WS,address:$ADDR" >>"$LOGFILE" 2>&1
      SEEN[$ADDR]=1
    fi
  done < <(hyprctl clients -j | jq -r '.[] | [.pid, .address, .class] | @tsv')

  sleep 0.01
done

printf "=== Deploy finished: '%q' ===\n" "${CMD[*]}" >>"$LOGFILE"
exit 0

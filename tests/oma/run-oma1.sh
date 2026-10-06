#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="$ROOT/oma-evidence"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE="$EVIDENCE_DIR/oma1-$TIMESTAMP.txt"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

error() {
  printf '[ERROR] %s\n' "$*" >&2
  if [[ -f "$EVIDENCE" ]]; then
    printf 'fatal_error=%s\n' "$*" >> "$EVIDENCE"
    sha256sum "$EVIDENCE" > "$EVIDENCE.sha256"
    printf 'O.M.A.-1 evidence written to %s\n' "$EVIDENCE" >&2
    printf 'O.M.A.-1 evidence SHA-256 written to %s.sha256\n' "$EVIDENCE" >&2
  fi
  exit 1
}

mkdir -p "$EVIDENCE_DIR"

for cmd in bash awk date mktemp mv tr uname id systemctl busctl hyprctl pactl awww pidof pgrep findmnt sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || error "Required O.M.A.-1 command unavailable: $cmd"
done

{
  printf 'mode=oma1-baseline\n'
  printf 'timestamp=%s\n' "$TIMESTAMP"
  printf 'hostname=%s\n' "$(uname -n)"
  printf 'user=%s\n' "$(id -un)"
  printf 'uid=%s\n' "$(id -u)"
  printf '\n[session_discovery]\n'
} > "$EVIDENCE"

GRAPHICAL_UID="$(id -u)"
if HYPRLAND_PID="$(
  pgrep -u "$GRAPHICAL_UID" -x Hyprland 2>/dev/null |
    awk 'NR==1{print; exit}'
)"; then
  :
else
  HYPRLAND_PID=
fi

if [[ -z "$HYPRLAND_PID" ]]; then
  printf 'hyprland_process=FAIL\n' >> "$EVIDENCE"
  printf 'reason=Active Hyprland compositor process was not found for the current user.\n' >> "$EVIDENCE"
  printf '\nsummary_failures=1\n' >> "$EVIDENCE"
  sha256sum "$EVIDENCE" > "$EVIDENCE.sha256"
  printf '[FAIL] O.M.A.-1 session discovery failed: active Hyprland compositor process was not found for the current user.\n' >&2
  printf 'O.M.A.-1 evidence written to %s\n' "$EVIDENCE" >&2
  printf 'O.M.A.-1 evidence SHA-256 written to %s.sha256\n' "$EVIDENCE" >&2
  exit 1
fi

printf 'hyprland_process=PASS\n' >> "$EVIDENCE"
printf 'pid=%s\n' "$HYPRLAND_PID" >> "$EVIDENCE"

HYPRLAND_ENV="/proc/$HYPRLAND_PID/environ"
[[ -r "$HYPRLAND_ENV" ]] || error "Hyprland process environment is unavailable: $HYPRLAND_ENV"

load_session_environment() {
  local key value found_wayland=0 found_runtime=0 found_desktop=0 found_session=0
  while IFS= read -r -d '' entry; do
    key="${entry%%=*}"
    value="${entry#*=}"
    case "$key" in
      WAYLAND_DISPLAY) export WAYLAND_DISPLAY="$value"; found_wayland=1 ;;
      XDG_RUNTIME_DIR) export XDG_RUNTIME_DIR="$value"; found_runtime=1 ;;
      XDG_CURRENT_DESKTOP) export XDG_CURRENT_DESKTOP="$value"; found_desktop=1 ;;
      XDG_SESSION_TYPE) export XDG_SESSION_TYPE="$value"; found_session=1 ;;
      DBUS_SESSION_BUS_ADDRESS) export DBUS_SESSION_BUS_ADDRESS="$value" ;;
    esac
  done < "$HYPRLAND_ENV"

  (( found_runtime )) || error 'Hyprland environment does not contain XDG_RUNTIME_DIR.'
  (( found_desktop )) || error 'Hyprland environment does not contain XDG_CURRENT_DESKTOP.'
  [[ -d "$XDG_RUNTIME_DIR" ]] || error "Hyprland XDG_RUNTIME_DIR is unavailable: $XDG_RUNTIME_DIR"
  [[ "$XDG_CURRENT_DESKTOP" == *Hyprland* || "$XDG_CURRENT_DESKTOP" == *hyprland* ]] ||
    error "Hyprland desktop session is not identified: $XDG_CURRENT_DESKTOP"
  [[ "$XDG_SESSION_TYPE" == "wayland" ]] ||
    error "Hyprland session type is not Wayland: ${XDG_SESSION_TYPE:-unset}"

  local process_wayland_display="${WAYLAND_DISPLAY:-}"
  local hyprland_wl_socket
  hyprland_wl_socket="$(
    hyprctl instances 2>/dev/null |
      awk -v target="$HYPRLAND_PID" '
        /^instance / { matched=0 }
        /^[[:space:]]*pid:/ { matched=($2 == target) }
        matched && /^[[:space:]]*wl socket:/ { print $3; exit }
      '
  )"
  [[ -n "$hyprland_wl_socket" ]] ||
    error "Hyprland instance record does not expose wl socket for PID $HYPRLAND_PID."

  local wayland_socket_path
  if [[ "$hyprland_wl_socket" == /* ]]; then
    wayland_socket_path="$hyprland_wl_socket"
    export WAYLAND_DISPLAY="$hyprland_wl_socket"
  else
    wayland_socket_path="$XDG_RUNTIME_DIR/$hyprland_wl_socket"
    export WAYLAND_DISPLAY="$hyprland_wl_socket"
  fi

  [[ -S "$wayland_socket_path" ]] ||
    error "Hyprland Wayland socket is unavailable: $wayland_socket_path."
  if (( found_wayland )) && [[ "$process_wayland_display" != "$WAYLAND_DISPLAY" ]]; then
    error "Hyprland process WAYLAND_DISPLAY does not match Hyprland instance wl socket: process=$process_wayland_display instance=$WAYLAND_DISPLAY"
  fi
}

load_session_environment

{
  printf '\n[session]\n'
  printf 'wayland_display=%s\n' "$WAYLAND_DISPLAY"
  printf 'wayland_display_source=hyprctl_instances\n'
  printf 'xdg_current_desktop=%s\n' "$XDG_CURRENT_DESKTOP"
  printf 'xdg_session_type=%s\n' "${XDG_SESSION_TYPE:-unset}"
  printf 'runtime_dir=%s\n' "$XDG_RUNTIME_DIR"
  printf '\n[probes]\n'
} >> "$EVIDENCE"

check() {
  local name="$1"
  shift
  if "$@" >"$TMP" 2>&1; then
    printf '%s=PASS\n' "$name" >> "$EVIDENCE"
    sed 's/[[:space:]]\+$//' "$TMP" | sed 's/^/  /' >> "$EVIDENCE"
  else
    printf '%s=FAIL\n' "$name" >> "$EVIDENCE"
    sed 's/[[:space:]]\+$//' "$TMP" | sed 's/^/  /' >> "$EVIDENCE"
    return 1
  fi
}

check_user_manager() {
  local state failed_units
  state="$(systemctl --user is-system-running 2>&1)" || true
  printf '  state=%s\n' "$state" > "$TMP"

  case "$state" in
    running)
      return 0
      ;;
    degraded)
      failed_units="$(systemctl --user --failed --no-legend --no-pager 2>&1 || true)"
      printf '%s\n' "$failed_units" >> "$TMP"
      return 1
      ;;
    *)
      printf '  failed_units:\n' >> "$TMP"
      systemctl --user --failed --no-legend --no-pager >> "$TMP" 2>&1 || true
      return 1
      ;;
  esac
}

failures=0
if check_user_manager; then
  printf 'user_manager=PASS\n' >> "$EVIDENCE"
  sed 's/[[:space:]]\+$//' "$TMP" | sed 's/^/  /' >> "$EVIDENCE"
else
  printf 'user_manager=FAIL\n' >> "$EVIDENCE"
  sed 's/[[:space:]]\+$//' "$TMP" | sed 's/^/  /' >> "$EVIDENCE"
  failures=$((failures + 1))
fi
check 'dbus_user_bus' busctl --user list || failures=$((failures + 1))
check 'hyprland_runtime' hyprctl monitors || failures=$((failures + 1))
check 'audio_server' pactl info || failures=$((failures + 1))
check 'wallpaper_runtime' awww query || failures=$((failures + 1))
check 'waybar_runtime' pidof waybar || failures=$((failures + 1))
check 'root_mount' findmnt -n / || failures=$((failures + 1))

printf '\nsummary_failures=%d\n' "$failures" >> "$EVIDENCE"

if ((failures)); then
  printf '[FAIL] O.M.A.-1 baseline failed with %d failed probe(s).\n' "$failures" >&2
  sha256sum "$EVIDENCE" > "$EVIDENCE.sha256"
  printf 'O.M.A.-1 evidence written to %s\n' "$EVIDENCE" >&2
  printf 'O.M.A.-1 evidence SHA-256 written to %s.sha256\n' "$EVIDENCE" >&2
  exit 1
fi

printf '[PASS] O.M.A.-1 runtime baseline passed without system mutation.\n'
sha256sum "$EVIDENCE" > "$EVIDENCE.sha256"
printf 'O.M.A.-1 evidence written to %s\n' "$EVIDENCE"
printf 'O.M.A.-1 evidence SHA-256 written to %s.sha256\n' "$EVIDENCE.sha256"

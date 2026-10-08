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
  local key value found_wayland=0 found_runtime=0 found_desktop=0 found_session=0 found_signature=0
  while IFS= read -r -d '' entry; do
    key="${entry%%=*}"
    value="${entry#*=}"
    case "$key" in
      WAYLAND_DISPLAY) export WAYLAND_DISPLAY="$value"; found_wayland=1 ;;
      XDG_RUNTIME_DIR) export XDG_RUNTIME_DIR="$value"; found_runtime=1 ;;
      XDG_CURRENT_DESKTOP) export XDG_CURRENT_DESKTOP="$value"; found_desktop=1 ;;
      XDG_SESSION_TYPE) export XDG_SESSION_TYPE="$value"; found_session=1 ;;
      DBUS_SESSION_BUS_ADDRESS) export DBUS_SESSION_BUS_ADDRESS="$value" ;;
      HYPRLAND_INSTANCE_SIGNATURE) export HYPRLAND_INSTANCE_SIGNATURE="$value"; found_signature=1 ;;
    esac
  done < "$HYPRLAND_ENV"

  local process_wayland_display="${WAYLAND_DISPLAY:-}"
  local hyprland_instance_record hyprland_wl_socket instance_signature
  hyprland_instance_record="$(
    hyprctl instances 2>/dev/null |
      awk -v target="$HYPRLAND_PID" '
        /^instance / { signature=$2; matched=0 }
        /^[[:space:]]*pid:/ { matched=($2 == target) }
        matched && /^[[:space:]]*wl socket:/ { print signature "\t" $3; exit }
      '
  )"
  IFS=$'\t' read -r instance_signature hyprland_wl_socket <<< "$hyprland_instance_record"
  [[ -n "$instance_signature" && -n "$hyprland_wl_socket" ]] ||
    error "Hyprland instance record does not expose signature and wl socket for PID $HYPRLAND_PID."

  if (( found_signature )); then
    [[ "$HYPRLAND_INSTANCE_SIGNATURE" == "$instance_signature" ]] ||
      error "Hyprland process instance signature does not match hyprctl instance: process=$HYPRLAND_INSTANCE_SIGNATURE instance=$instance_signature"
    HYPRLAND_INSTANCE_SIGNATURE_SOURCE="hyprland_process_environment"
  else
    HYPRLAND_INSTANCE_SIGNATURE="$instance_signature"
    export HYPRLAND_INSTANCE_SIGNATURE
    HYPRLAND_INSTANCE_SIGNATURE_SOURCE="hyprctl_instances"
  fi
  local wayland_socket_path derived_runtime_dir
  if [[ "$hyprland_wl_socket" == /* ]]; then
    wayland_socket_path="$hyprland_wl_socket"
    derived_runtime_dir="${hyprland_wl_socket%/*}"
    [[ -n "$derived_runtime_dir" ]] || derived_runtime_dir="/"
    export WAYLAND_DISPLAY="$hyprland_wl_socket"
  else
    [[ -n "${XDG_RUNTIME_DIR:-}" ]] || XDG_RUNTIME_DIR="/run/user/$(id -u)"
    wayland_socket_path="$XDG_RUNTIME_DIR/$hyprland_wl_socket"
    derived_runtime_dir="$XDG_RUNTIME_DIR"
    export WAYLAND_DISPLAY="$hyprland_wl_socket"
  fi

  [[ -S "$wayland_socket_path" ]] ||
    error "Hyprland Wayland socket is unavailable: $wayland_socket_path."

  if (( found_runtime )); then
    [[ -d "$XDG_RUNTIME_DIR" ]] ||
      error "Hyprland XDG_RUNTIME_DIR is unavailable: $XDG_RUNTIME_DIR"
    [[ "$XDG_RUNTIME_DIR" == "$derived_runtime_dir" ]] ||
      error "Hyprland XDG_RUNTIME_DIR does not match Wayland socket parent: environment=$XDG_RUNTIME_DIR socket_parent=$derived_runtime_dir"
    XDG_RUNTIME_DIR_SOURCE="hyprland_process_environment"
  else
    XDG_RUNTIME_DIR="$derived_runtime_dir"
    export XDG_RUNTIME_DIR
    XDG_RUNTIME_DIR_SOURCE="wayland_socket_parent"
  fi

  if (( found_desktop )); then
    [[ "$XDG_CURRENT_DESKTOP" == *Hyprland* || "$XDG_CURRENT_DESKTOP" == *hyprland* ]] ||
      error "Hyprland desktop session is not identified: $XDG_CURRENT_DESKTOP"
    XDG_CURRENT_DESKTOP_SOURCE="hyprland_process_environment"
  else
    XDG_CURRENT_DESKTOP="Hyprland"
    export XDG_CURRENT_DESKTOP
    XDG_CURRENT_DESKTOP_SOURCE="hyprland_process_identity"
  fi

  if (( found_session )) && [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    XDG_SESSION_TYPE_SOURCE="hyprland_process_environment"
  elif [[ "${XDG_SESSION_TYPE:-}" == "tty" ]]; then
    # A Hyprland compositor launched from a console can inherit the login
    # session's tty marker. The verified compositor-owned Wayland socket is
    # authoritative for the graphical session under certification.
    XDG_SESSION_TYPE="wayland"
    export XDG_SESSION_TYPE
    XDG_SESSION_TYPE_SOURCE="wayland_socket_overrides_tty"
  else
    XDG_SESSION_TYPE="wayland"
    export XDG_SESSION_TYPE
    XDG_SESSION_TYPE_SOURCE="wayland_socket"
  fi

  [[ -d "$XDG_RUNTIME_DIR" ]] ||
    error "Resolved XDG_RUNTIME_DIR is unavailable: $XDG_RUNTIME_DIR"

  if (( found_wayland )) && [[ "$process_wayland_display" != "$WAYLAND_DISPLAY" ]]; then
    error "Hyprland process WAYLAND_DISPLAY does not match Hyprland instance wl socket: process=$process_wayland_display instance=$WAYLAND_DISPLAY"
  fi
}

load_session_environment

{
  printf '\n[session]\n'
  printf 'hyprland_instance_signature=%s\n' "$HYPRLAND_INSTANCE_SIGNATURE"
  printf 'hyprland_instance_signature_source=%s\n' "$HYPRLAND_INSTANCE_SIGNATURE_SOURCE"
  printf 'wayland_display=%s\n' "$WAYLAND_DISPLAY"
  printf 'wayland_display_source=hyprctl_instances\n'
  printf 'xdg_current_desktop=%s\n' "$XDG_CURRENT_DESKTOP"
  printf 'xdg_current_desktop_source=%s\n' "$XDG_CURRENT_DESKTOP_SOURCE"
  printf 'xdg_session_type=%s\n' "${XDG_SESSION_TYPE:-unset}"
  printf 'xdg_session_type_source=%s\n' "$XDG_SESSION_TYPE_SOURCE"
  printf 'runtime_dir=%s\n' "$XDG_RUNTIME_DIR"
  printf 'xdg_runtime_dir_source=%s\n' "$XDG_RUNTIME_DIR_SOURCE"
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

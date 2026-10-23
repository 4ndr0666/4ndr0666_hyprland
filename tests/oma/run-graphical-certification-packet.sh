#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="$ROOT/oma-evidence"
PACKET_TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
PACKET_EVIDENCE="$EVIDENCE_DIR/graphical-certification-$PACKET_TIMESTAMP.txt"
PACKET_TMP="$(mktemp)"

fail() {
  if [[ -f "${PACKET_EVIDENCE:-}" ]]; then
    printf 'fatal_error=%s\n' "$*" >> "$PACKET_EVIDENCE"
  fi
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command unavailable: $1"
}

for cmd in bash date git sed sha256sum pgrep id uname hyprctl awk; do
  require_command "$cmd"
done

[[ -f "$ROOT/tests/oma/run-oma1.sh" && -x "$ROOT/tests/oma/run-oma1.sh" ]] ||
  fail "O.M.A.-1 runner is unavailable or not executable."
[[ -f "$ROOT/tests/oma/run-oma2.sh" && -x "$ROOT/tests/oma/run-oma2.sh" ]] ||
  fail "O.M.A.-2 runner is unavailable or not executable."
[[ -f "$ROOT/tests/unit/run-golden-units.sh" && -x "$ROOT/tests/unit/run-golden-units.sh" ]] ||
  fail "Golden Unit runner is unavailable or not executable."

mkdir -p "$EVIDENCE_DIR"

HEAD_SHA="$(git -C "$ROOT" rev-parse HEAD)"
BRANCH="$(git -C "$ROOT" branch --show-current)"
ROOT_REAL="$(git -C "$ROOT" rev-parse --show-toplevel)"

{
  printf 'mode=graphical-certification-packet\n'
  printf 'timestamp=%s\n' "$PACKET_TIMESTAMP"
  printf 'hostname=%s\n' "$(uname -n)"
  printf 'user=%s\n' "$(id -un)"
  printf 'uid=%s\n' "$(id -u)"
  printf 'repo_root=%s\n' "$ROOT_REAL"
  printf 'branch=%s\n' "$BRANCH"
  printf 'head=%s\n' "$HEAD_SHA"
  printf '\n[graphical_preflight]\n'
} > "$PACKET_EVIDENCE"

packet_exit() {
  local status="$?"
  if [[ -f "$PACKET_EVIDENCE" && ! -f "$PACKET_EVIDENCE.sha256" ]]; then
    printf 'exit_status=%s\n' "$status" >> "$PACKET_EVIDENCE"
    sha256sum "$PACKET_EVIDENCE" > "$PACKET_EVIDENCE.sha256"
  fi
  rm -f -- "$PACKET_TMP"
  trap - EXIT
  exit "$status"
}

trap packet_exit EXIT

HYPRLAND_PID="$(pgrep -u "$(id -u)" -x Hyprland 2>/dev/null | while IFS= read -r pid; do printf '%s' "$pid"; break; done || true)"
if [[ -z "$HYPRLAND_PID" ]]; then
  printf 'hyprland_process=FAIL\n' >> "$PACKET_EVIDENCE"
  printf 'reason=Active Hyprland compositor process was not found for the current user.\n' >> "$PACKET_EVIDENCE"
  printf '\nsummary=BLOCKED\n' >> "$PACKET_EVIDENCE"
  printf '[BLOCKED] No active Hyprland process was found. Enter the graphical Hyprland session and rerun this packet.\n' >&2
  printf 'Evidence: %s\n' "$PACKET_EVIDENCE" >&2
  printf 'Evidence SHA-256: %s.sha256\n' "$PACKET_EVIDENCE" >&2
  exit 2
fi

HYPRLAND_ENV="/proc/$HYPRLAND_PID/environ"
[[ -r "$HYPRLAND_ENV" ]] || fail "Hyprland environment is unavailable: $HYPRLAND_ENV"

SESSION_ENV="$PACKET_TMP"
found_wayland=0
found_runtime=0
found_desktop=0
found_session=0
while IFS= read -r -d '' entry; do
  key="${entry%%=*}"
  value="${entry#*=}"
  case "$key" in
    WAYLAND_DISPLAY)
      printf '%s\n' "$entry" >> "$SESSION_ENV"
      WAYLAND_DISPLAY_VALUE="$value"
      found_wayland=1
      ;;
    XDG_RUNTIME_DIR)
      printf '%s\n' "$entry" >> "$SESSION_ENV"
      XDG_RUNTIME_DIR_VALUE="$value"
      found_runtime=1
      ;;
    XDG_CURRENT_DESKTOP)
      printf '%s\n' "$entry" >> "$SESSION_ENV"
      XDG_CURRENT_DESKTOP_VALUE="$value"
      found_desktop=1
      ;;
    XDG_SESSION_TYPE)
      printf '%s\n' "$entry" >> "$SESSION_ENV"
      XDG_SESSION_TYPE_VALUE="$value"
      found_session=1
      ;;
    DBUS_SESSION_BUS_ADDRESS)
      printf '%s\n' "$entry" >> "$SESSION_ENV"
      DBUS_SESSION_BUS_ADDRESS_VALUE="$value"
      ;;
  esac
done < "$HYPRLAND_ENV"

PROCESS_WAYLAND_DISPLAY_VALUE="${WAYLAND_DISPLAY_VALUE:-}"
HYPRLAND_WL_SOCKET="$(
  hyprctl instances 2>/dev/null |
    awk -v target="$HYPRLAND_PID" '
      /^instance / { matched=0 }
      /^[[:space:]]*pid:/ { matched=($2 == target) }
      matched && /^[[:space:]]*wl socket:/ { print $3; exit }
    '
)"
[[ -n "$HYPRLAND_WL_SOCKET" ]] || fail "Hyprland instance record does not expose wl socket for PID $HYPRLAND_PID."

if [[ "$HYPRLAND_WL_SOCKET" == /* ]]; then
  WAYLAND_SOCKET_PATH="$HYPRLAND_WL_SOCKET"
  WAYLAND_DISPLAY_VALUE="$HYPRLAND_WL_SOCKET"
  DERIVED_RUNTIME_DIR="${HYPRLAND_WL_SOCKET%/*}"
  [[ -n "$DERIVED_RUNTIME_DIR" ]] || DERIVED_RUNTIME_DIR="/"
else
  [[ -n "${XDG_RUNTIME_DIR_VALUE:-}" ]] || XDG_RUNTIME_DIR_VALUE="/run/user/$(id -u)"
  WAYLAND_SOCKET_PATH="$XDG_RUNTIME_DIR_VALUE/$HYPRLAND_WL_SOCKET"
  WAYLAND_DISPLAY_VALUE="$HYPRLAND_WL_SOCKET"
  DERIVED_RUNTIME_DIR="$XDG_RUNTIME_DIR_VALUE"
fi

[[ -S "$WAYLAND_SOCKET_PATH" ]] || fail "Hyprland Wayland socket is unavailable: $WAYLAND_SOCKET_PATH."

if (( found_runtime )); then
  XDG_RUNTIME_DIR_SOURCE="hyprland_process_environment"
  [[ -d "$XDG_RUNTIME_DIR_VALUE" ]] || fail "Hyprland XDG_RUNTIME_DIR is unavailable: $XDG_RUNTIME_DIR_VALUE."
  [[ "$XDG_RUNTIME_DIR_VALUE" == "$DERIVED_RUNTIME_DIR" ]] ||
    fail "Hyprland XDG_RUNTIME_DIR does not match Wayland socket parent: environment=$XDG_RUNTIME_DIR_VALUE socket_parent=$DERIVED_RUNTIME_DIR."
else
  XDG_RUNTIME_DIR_VALUE="$DERIVED_RUNTIME_DIR"
  found_runtime=1
  XDG_RUNTIME_DIR_SOURCE="wayland_socket_parent"
  printf 'XDG_RUNTIME_DIR=%s\n' "$XDG_RUNTIME_DIR_VALUE" >> "$SESSION_ENV"
fi

if (( found_desktop )); then
  [[ "$XDG_CURRENT_DESKTOP_VALUE" == *Hyprland* || "$XDG_CURRENT_DESKTOP_VALUE" == *hyprland* ]] ||
    fail "Hyprland desktop marker is not present: $XDG_CURRENT_DESKTOP_VALUE."
  XDG_CURRENT_DESKTOP_SOURCE="hyprland_process_environment"
else
  XDG_CURRENT_DESKTOP_VALUE="Hyprland"
  XDG_CURRENT_DESKTOP_SOURCE="hyprland_process_identity"
fi

if (( found_session )) && [[ "$XDG_SESSION_TYPE_VALUE" == wayland ]]; then
  XDG_SESSION_TYPE_SOURCE="hyprland_process_environment"
elif [[ "${XDG_SESSION_TYPE_VALUE:-}" == tty ]]; then
  # A Hyprland compositor launched from a console can inherit the login
  # session's tty marker. The verified compositor-owned Wayland socket is
  # authoritative for the graphical session under certification.
  XDG_SESSION_TYPE_VALUE="wayland"
  XDG_SESSION_TYPE_SOURCE="wayland_socket_overrides_tty"
else
  XDG_SESSION_TYPE_VALUE="wayland"
  XDG_SESSION_TYPE_SOURCE="wayland_socket"
fi

[[ -d "$XDG_RUNTIME_DIR_VALUE" ]] || fail "Resolved XDG_RUNTIME_DIR is unavailable: $XDG_RUNTIME_DIR_VALUE."

if (( found_wayland )) && [[ "$PROCESS_WAYLAND_DISPLAY_VALUE" != "$WAYLAND_DISPLAY_VALUE" ]]; then
  fail "Hyprland process WAYLAND_DISPLAY does not match Hyprland instance wl socket: process=$PROCESS_WAYLAND_DISPLAY_VALUE instance=$WAYLAND_DISPLAY_VALUE."
fi

{
  printf 'hyprland_process=PASS\n'
  printf 'hyprland_pid=%s\n' "$HYPRLAND_PID"
  printf 'environment_source=%s\n' "$HYPRLAND_ENV"
  printf 'wayland_display_source=hyprctl_instances\n'
  printf 'hyprland_wl_socket=%s\n' "$HYPRLAND_WL_SOCKET"
  printf 'wayland_display=%s\n' "$WAYLAND_DISPLAY_VALUE"
  printf 'xdg_runtime_dir=%s\n' "$XDG_RUNTIME_DIR_VALUE"
  printf 'xdg_runtime_dir_source=%s\n' "$XDG_RUNTIME_DIR_SOURCE"
  printf 'xdg_current_desktop=%s\n' "$XDG_CURRENT_DESKTOP_VALUE"
  printf 'xdg_current_desktop_source=%s\n' "$XDG_CURRENT_DESKTOP_SOURCE"
  printf 'xdg_session_type=%s\n' "$XDG_SESSION_TYPE_VALUE"
  printf 'xdg_session_type_source=%s\n' "$XDG_SESSION_TYPE_SOURCE"
  printf 'dbus_session_bus_present=%s\n' "$([[ -n "$DBUS_SESSION_BUS_ADDRESS_VALUE" ]] && printf yes || printf no)"
} >> "$PACKET_EVIDENCE"

export WAYLAND_DISPLAY="$WAYLAND_DISPLAY_VALUE"
export XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR_VALUE"
export XDG_CURRENT_DESKTOP="$XDG_CURRENT_DESKTOP_VALUE"
export XDG_SESSION_TYPE="$XDG_SESSION_TYPE_VALUE"
[[ -n "$DBUS_SESSION_BUS_ADDRESS_VALUE" ]] && export DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS_VALUE"

printf '\n[golden_unit_gate]\n' >> "$PACKET_EVIDENCE"
if "$ROOT/tests/unit/run-golden-units.sh" >"$PACKET_TMP" 2>&1; then
  printf 'golden_units=PASS\n' >> "$PACKET_EVIDENCE"
  sed 's/[[:space:]]\+$//' "$PACKET_TMP" | sed 's/^/  /' >> "$PACKET_EVIDENCE"
else
  printf 'golden_units=FAIL\n' >> "$PACKET_EVIDENCE"
  sed 's/[[:space:]]\+$//' "$PACKET_TMP" | sed 's/^/  /' >> "$PACKET_EVIDENCE"
  printf '\nsummary=BLOCKED\n' >> "$PACKET_EVIDENCE"
  printf '[FAIL] Golden Unit gate failed; O.M.A. runtime certification was not attempted.\n' >&2
  printf 'Evidence: %s\n' "$PACKET_EVIDENCE" >&2
  printf 'Evidence SHA-256: %s.sha256\n' "$PACKET_EVIDENCE.sha256" >&2
  exit 1
fi

# Installation readiness is separate from runtime certification: this gate is read-only
# and must never launch services to make the later O.M.A.-1 probes pass.
printf '\n[installation_readiness]\n' >> "$PACKET_EVIDENCE"
readiness_failures=()

check_deployed_file() {
  local path="$1"
  local description="$2"
  if [[ -f "$path" && -r "$path" ]]; then
    printf '%s=PASS\n' "$description" >> "$PACKET_EVIDENCE"
  else
    printf '%s=FAIL\n' "$description" >> "$PACKET_EVIDENCE"
    readiness_failures+=("$description: missing or unreadable file $path")
  fi
}

check_runtime_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf 'runtime_command_%s=PASS\n' "$name" >> "$PACKET_EVIDENCE"
  else
    printf 'runtime_command_%s=FAIL\n' "$name" >> "$PACKET_EVIDENCE"
    readiness_failures+=("required runtime command is unavailable: $name")
  fi
}

check_binary_candidates() {
  local description="$1"
  shift
  local candidate
  for candidate in "$@"; do
    if [[ -x "$candidate" ]]; then
      printf '%s=PASS\n' "$description" >> "$PACKET_EVIDENCE"
      return 0
    fi
  done
  printf '%s=FAIL\n' "$description" >> "$PACKET_EVIDENCE"
  readiness_failures+=("no executable found for $description (checked: $*)")
}

HYPR_CONFIG="$HOME/.config/hypr"
check_deployed_file "$HYPR_CONFIG/UserScripts/4ndr0init.sh" "deployed_initializer"
if [[ -x "$HYPR_CONFIG/UserScripts/4ndr0init.sh" ]]; then
  printf 'deployed_initializer_executable=PASS\n' >> "$PACKET_EVIDENCE"
else
  printf 'deployed_initializer_executable=FAIL\n' >> "$PACKET_EVIDENCE"
  readiness_failures+=("deployed initializer is not executable: $HYPR_CONFIG/UserScripts/4ndr0init.sh")
fi
check_deployed_file "$HYPR_CONFIG/configs/Startup_Apps.lua" "deployed_startup_module"
if [[ -r "$HYPR_CONFIG/configs/Startup_Apps.lua" ]] &&
   grep -Fq 'hl.exec_cmd(UserScripts .. "/4ndr0init.sh")' "$HYPR_CONFIG/configs/Startup_Apps.lua" &&
   grep -Fq 'hl.on("hyprland.start"' "$HYPR_CONFIG/configs/Startup_Apps.lua"; then
  printf 'deployed_initializer_hook=PASS\n' >> "$PACKET_EVIDENCE"
else
  printf 'deployed_initializer_hook=FAIL\n' >> "$PACKET_EVIDENCE"
  readiness_failures+=("deployed Startup_Apps.lua does not register the required hyprland.start initializer hook")
fi
check_deployed_file "$HYPR_CONFIG/hyprland.lua" "deployed_hyprland_entrypoint"
if [[ -r "$HYPR_CONFIG/hyprland.lua" ]] &&
   grep -Fq 'source("configs.Startup_Apps")' "$HYPR_CONFIG/hyprland.lua"; then
  printf 'deployed_startup_loader=PASS\n' >> "$PACKET_EVIDENCE"
else
  printf 'deployed_startup_loader=FAIL\n' >> "$PACKET_EVIDENCE"
  readiness_failures+=("deployed hyprland.lua does not load configs.Startup_Apps")
fi

for runtime_command in dbus-send dbus-launch dbus-update-activation-environment systemctl killall awww-daemon awww waybar; do
  check_runtime_command "$runtime_command"
done
check_binary_candidates "hyprland_portal_binary" \
  /usr/lib/xdg-desktop-portal-hyprland /usr/libexec/xdg-desktop-portal-hyprland
check_binary_candidates "generic_portal_binary" \
  /usr/lib/xdg-desktop-portal /usr/libexec/xdg-desktop-portal

if (("${#readiness_failures[@]}" > 0)); then
  printf 'installation_readiness=BLOCKED\n' >> "$PACKET_EVIDENCE"
  printf 'oma1=NOT_RUN\n' >> "$PACKET_EVIDENCE"
  printf 'oma2=NOT_RUN\n' >> "$PACKET_EVIDENCE"
  printf 'readiness_failure_count=%d\n' "${#readiness_failures[@]}" >> "$PACKET_EVIDENCE"
  printf '%s\n' "${readiness_failures[@]}" | sed 's/^/readiness_failure=/' >> "$PACKET_EVIDENCE"
  printf '\nsummary=BLOCKED\n' >> "$PACKET_EVIDENCE"
  printf '[BLOCKED] Installation readiness failed; O.M.A.-1 and O.M.A.-2 were not run. This packet did not start or repair services.\n' >&2
  printf 'Evidence: %s\n' "$PACKET_EVIDENCE" >&2
  printf 'Evidence SHA-256: %s.sha256\n' "$PACKET_EVIDENCE.sha256" >&2
  exit 2
fi

printf 'installation_readiness=PASS\n' >> "$PACKET_EVIDENCE"

printf '\n[oma1]\n' >> "$PACKET_EVIDENCE"
if "$ROOT/tests/oma/run-oma1.sh" >"$PACKET_TMP" 2>&1; then
  printf 'oma1=PASS\n' >> "$PACKET_EVIDENCE"
  sed 's/[[:space:]]\+$//' "$PACKET_TMP" | sed 's/^/  /' >> "$PACKET_EVIDENCE"
else
  printf 'oma1=FAIL\n' >> "$PACKET_EVIDENCE"
  sed 's/[[:space:]]\+$//' "$PACKET_TMP" | sed 's/^/  /' >> "$PACKET_EVIDENCE"
  printf '\n[contingency]\n' >> "$PACKET_EVIDENCE"
  printf 'oma2=NOT_RUN\n' >> "$PACKET_EVIDENCE"
  printf 'action=STOP_AND_REVIEW_OMA1_EVIDENCE\n' >> "$PACKET_EVIDENCE"
  printf '\nsummary=BLOCKED\n' >> "$PACKET_EVIDENCE"
  printf '[FAIL] O.M.A.-1 baseline failed; O.M.A.-2 was intentionally not run.\n' >&2
  printf 'Evidence: %s\n' "$PACKET_EVIDENCE" >&2
  printf 'Evidence SHA-256: %s.sha256\n' "$PACKET_EVIDENCE.sha256" >&2
  exit 1
fi

printf '\n[oma2_safe]\n' >> "$PACKET_EVIDENCE"
if "$ROOT/tests/oma/run-oma2.sh" --safe >"$PACKET_TMP" 2>&1; then
  printf 'oma2_safe=PASS\n' >> "$PACKET_EVIDENCE"
  sed 's/[[:space:]]\+$//' "$PACKET_TMP" | sed 's/^/  /' >> "$PACKET_EVIDENCE"
else
  printf 'oma2_safe=FAIL\n' >> "$PACKET_EVIDENCE"
  sed 's/[[:space:]]\+$//' "$PACKET_TMP" | sed 's/^/  /' >> "$PACKET_EVIDENCE"
  printf '\nsummary=FAIL\n' >> "$PACKET_EVIDENCE"
  printf '[FAIL] O.M.A.-2 safe certification failed. No destructive run was attempted.\n' >&2
  printf 'Evidence: %s\n' "$PACKET_EVIDENCE" >&2
  printf 'Evidence SHA-256: %s.sha256\n' "$PACKET_EVIDENCE.sha256" >&2
  exit 1
fi

printf '\n[completion]\n' >> "$PACKET_EVIDENCE"
printf 'oma2_destructive=NOT_RUN\n' >> "$PACKET_EVIDENCE"
printf 'system_mutation=NONE_BY_THIS_PACKET\n' >> "$PACKET_EVIDENCE"
printf 'summary=PASS\n' >> "$PACKET_EVIDENCE"
sha256sum "$PACKET_EVIDENCE" > "$PACKET_EVIDENCE.sha256"

printf '[PASS] Graphical O.M.A. certification packet completed: O.M.A.-1 + O.M.A.-2 --safe.\n'
printf 'Packet evidence: %s\n' "$PACKET_EVIDENCE"
printf 'Packet evidence SHA-256: %s.sha256\n' "$PACKET_EVIDENCE.sha256"

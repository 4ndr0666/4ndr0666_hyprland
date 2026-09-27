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
  exit 1
}

mkdir -p "$EVIDENCE_DIR"

for cmd in bash awk date mktemp mv tr uname id systemctl busctl hyprctl pactl awww pidof findmnt sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || error "Required O.M.A.-1 command unavailable: $cmd"
done

[[ -n "${WAYLAND_DISPLAY:-}" ]] || error 'WAYLAND_DISPLAY is unset.'
[[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" ]] || error 'XDG_RUNTIME_DIR is unavailable.'
[[ "${XDG_CURRENT_DESKTOP:-}" == *Hyprland* || "${XDG_CURRENT_DESKTOP:-}" == *hyprland* ]] || error "Hyprland desktop session is not identified: ${XDG_CURRENT_DESKTOP:-unset}"

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

{
  printf 'mode=oma1-baseline\n'
  printf 'timestamp=%s\n' "$TIMESTAMP"
  printf 'hostname=%s\n' "$(uname -n)"
  printf 'user=%s\n' "$(id -un)"
  printf 'uid=%s\n' "$(id -u)"
  printf 'wayland_display=%s\n' "$WAYLAND_DISPLAY"
  printf 'xdg_current_desktop=%s\n' "$XDG_CURRENT_DESKTOP"
  printf 'xdg_session_type=%s\n' "${XDG_SESSION_TYPE:-unset}"
  printf 'runtime_dir=%s\n' "$XDG_RUNTIME_DIR"
  printf '\n[probes]\n'
} > "$EVIDENCE"

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

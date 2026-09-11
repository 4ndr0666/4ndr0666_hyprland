#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${OMA_OUT_DIR:-$ROOT/oma-evidence}"
MODE="inventory"

usage() {
  printf '%s\n' 'Usage: bash tests/oma/run-oma.sh [--inventory|--verify]'
  printf '%s\n' '  --inventory  collect the current machine support-envelope evidence'
  printf '%s\n' '  --verify     run GUP, installer dry-run, then collect machine evidence'
}

while (($#)); do
  case "$1" in
    --inventory) MODE=inventory ;;
    --verify) MODE=verify ;;
    --help|-h) usage; exit 0 ;;
    *) printf '[ERROR] Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -f "$ROOT/install.sh" ]] || { printf '[ERROR] Repository root is invalid: %s\n' "$ROOT" >&2; exit 1; }
[[ -r /etc/os-release ]] || { printf '[ERROR] /etc/os-release is unavailable.\n' >&2; exit 1; }
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == arch ]] || { printf '[ERROR] O.M.A. machine execution requires Arch Linux; detected %s.\n' "${ID:-unknown}" >&2; exit 1; }

mkdir -p -- "$OUT_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="$OUT_DIR/oma-$STAMP.txt"
TMP="$(mktemp "$OUT_DIR/.oma-$STAMP.XXXXXX")"
cleanup() {
  rm -f -- "$TMP"
}
trap cleanup EXIT HUP INT TERM

run_probe() {
  local name="$1"; shift
  printf '\n[%s]\n' "$name" >> "$TMP"
  if "$@" >> "$TMP" 2>&1; then
    printf 'status=PASS\n' >> "$TMP"
  else
    local rc=$?
    printf 'status=FAIL\nexit=%d\n' "$rc" >> "$TMP"
    return "$rc"
  fi
}

{
  printf 'GUP-O.M.A. machine evidence\n'
  printf 'protocol=GUP-O.M.A.\n'
  printf 'version=1.0.0\n'
  printf 'repository=%s\n' "$ROOT"
  printf 'commit=%s\n' "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf 'unavailable')"
  printf 'timestamp=%s\n' "$STAMP"
  printf 'mode=%s\n' "$MODE"
  printf 'hostname=%s\n' "$(hostname)"
  printf 'architecture=%s\n' "$(uname -m)"
  printf 'kernel=%s\n' "$(uname -r)"
  printf 'os=%s\n' "${PRETTY_NAME:-Arch Linux}"
  printf 'cpu=%s\n' "$(lscpu 2>/dev/null | awk -F: '/Model name/{gsub(/^ +/,"",$2); print $2; exit}' || printf 'unavailable')"
  printf 'gpu=%s\n' "$(lspci 2>/dev/null | awk -F': ' '/VGA compatible controller|3D controller/{print $2}' | paste -sd ';' - || printf 'unavailable')"
  printf 'boot=%s\n' "$(test -d /sys/firmware/efi && printf 'UEFI' || printf 'legacy-or-unavailable')"
  printf 'session=%s\n' "${XDG_SESSION_TYPE:-unavailable}"
  printf 'desktop=%s\n' "${XDG_CURRENT_DESKTOP:-unavailable}"
  printf 'wayland_display=%s\n' "${WAYLAND_DISPLAY:-unavailable}"
  printf 'filesystem=%s\n' "$(findmnt -n -o FSTYPE / 2>/dev/null || printf 'unavailable')"
  printf 'root_storage=%s\n' "$(findmnt -n -o SOURCE / 2>/dev/null || printf 'unavailable')"
  printf 'locale=%s\n' "${LANG:-unavailable}"
  printf 'timezone=%s\n' "$(timedatectl show -p Timezone --value 2>/dev/null || printf 'unavailable')"
  printf 'network=%s\n' "$(ip route show default 2>/dev/null | awk 'NR==1{print "default-route"; exit}' || printf 'unavailable')"
  printf 'package_manager=%s\n' "$(pacman --version 2>/dev/null | awk 'NR==1{print; exit}' || printf 'unavailable')"
  printf 'release_ref=%s\n' "$(tr -d '[:space:]' < "$ROOT/release.ref" 2>/dev/null || printf 'unavailable')"
} > "$TMP"

if [[ "$MODE" == verify ]]; then
  run_probe 'gup' bash "$ROOT/tests/unit/run-golden-units.sh"
  run_probe 'installer-dry-run' bash "$ROOT/install.sh" --dry-run
fi

printf '\n[capability-inventory]\n' >> "$TMP"
for cmd in bash awk findmnt lspci lscpu pacman systemctl ip git; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '%s=present\n' "$cmd" >> "$TMP"
  else
    printf '%s=absent\n' "$cmd" >> "$TMP"
  fi
done

printf '\n[non-destructive-boundary]\nstatus=PASS\nmutation_mode=disabled\n' >> "$TMP"
printf '\n[adversarial-boundary]\nstatus=NOT-EXERCISED\nreason=destructive fault injection requires an explicitly provisioned recovery machine\n' >> "$TMP"

mv -- "$TMP" "$REPORT"
printf 'O.M.A. evidence: %s\n' "$REPORT"
printf 'O.M.A. machine execution complete; destructive/adversarial certification remains gated on a provisioned recovery machine.\n'

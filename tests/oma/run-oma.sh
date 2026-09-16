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
# shellcheck disable=SC1091
source "$ROOT/install-scripts/core/platform.sh"
if ! is_arch_family; then
  printf '[ERROR] O.M.A. machine execution requires an Arch-family distribution; detected %s.\n' "${PRETTY_NAME:-${ID:-unknown}}" >&2
  exit 1
fi

for cmd in bash awk findmnt lspci lscpu pacman systemctl ip git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf '[ERROR] Required O.M.A. host capability is missing: %s\n' "$cmd" >&2
    exit 1
  fi
done

mkdir -p -- "$OUT_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="$OUT_DIR/oma-$STAMP.txt"
TMP="$(mktemp "$OUT_DIR/.oma-$STAMP.XXXXXX")"
finalize() {
  local rc=$?
  if [[ -f "$TMP" ]]; then
    mv -- "$TMP" "$REPORT"
  fi
  exit "$rc"
}
trap finalize EXIT

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
  printf 'version=1.1\n'
  printf 'repository=%s\n' "$ROOT"
  printf 'commit=%s\n' "$(git -C "$ROOT" rev-parse HEAD)"
  printf 'timestamp=%s\n' "$STAMP"
  printf 'mode=%s\n' "$MODE"
  printf 'hostname=%s\n' "$(uname -n)"
  printf 'architecture=%s\n' "$(uname -m)"
  printf 'kernel=%s\n' "$(uname -r)"
  printf 'os_id=%s\n' "${ID:-unknown}"
  printf 'os_id_like=%s\n' "${ID_LIKE:-unknown}"
  printf 'os=%s\n' "${PRETTY_NAME:-Arch-family Linux}"
  printf 'cpu=%s\n' "$(lscpu | awk -F: '/Model name/{gsub(/^ +/,"",$2); print $2; exit}')"
  printf 'gpu=%s\n' "$(lspci | awk -F': ' '/VGA compatible controller|3D controller/{print $2}' | paste -sd ';' -)"
  printf 'boot=%s\n' "$(test -d /sys/firmware/efi && printf 'UEFI' || printf 'legacy-or-unavailable')"
  printf 'session=%s\n' "${XDG_SESSION_TYPE:-unavailable}"
  printf 'desktop=%s\n' "${XDG_CURRENT_DESKTOP:-unavailable}"
  printf 'wayland_display=%s\n' "${WAYLAND_DISPLAY:-unavailable}"
  printf 'filesystem=%s\n' "$(findmnt -n -o FSTYPE /)"
  printf 'root_storage=%s\n' "$(findmnt -n -o SOURCE /)"
  printf 'locale=%s\n' "${LANG:-unavailable}"
  printf 'timezone=%s\n' "$(timedatectl show -p Timezone --value 2>/dev/null || printf 'unavailable')"
  printf 'network=%s\n' "$(ip route show default | awk 'NR==1{print "default-route"; exit}')"
  printf 'package_manager=%s\n' "$(pacman --version | awk 'NR==1{print; exit}')"
  printf 'release_ref=%s\n' "$(tr -d '[:space:]' < "$ROOT/release.ref")"
} > "$TMP"

if [[ "$MODE" == verify ]]; then
  run_probe 'gup' bash "$ROOT/tests/unit/run-golden-units.sh"
  run_probe 'installer-dry-run' bash "$ROOT/install.sh" --dry-run
fi

printf '\n[capability-inventory]\n' >> "$TMP"
for cmd in bash awk findmnt lspci lscpu pacman systemctl ip git; do
  printf '%s=present\n' "$cmd" >> "$TMP"
done

printf '%s\n' "O.M.A. $MODE evidence written to $REPORT"

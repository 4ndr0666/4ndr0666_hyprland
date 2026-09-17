#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="$ROOT/oma-evidence"
MODE="${1:---inventory}"

case "$MODE" in
  --inventory|--verify) ;;
  *)
    printf '[ERROR] Unsupported O.M.A. mode: %s\n' "$MODE" >&2
    printf '%s\n' 'Usage: run-oma.sh [--inventory|--verify]' >&2
    exit 2
    ;;
esac

mkdir -p "$EVIDENCE_DIR"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

error() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

for cmd in bash awk findmnt lspci lscpu pacman systemctl ip git date mktemp mv tr; do
  command -v "$cmd" >/dev/null 2>&1 || error "Required O.M.A. command unavailable: $cmd"
done

[[ -r /etc/os-release ]] || error '/etc/os-release is unavailable.'
# shellcheck disable=SC1091
source /etc/os-release
# shellcheck disable=SC1091
source "$ROOT/install-scripts/core/platform.sh"
is_arch_family "${ID:-}" "${ID_LIKE:-}" || error "O.M.A. requires an Arch-family host: ${PRETTY_NAME:-unknown}"

CPU_MODEL="$(lscpu | awk -F: '/Model name/{gsub(/^ +/,"",$2); print $2; exit}')"
GPU_INFO="$(lspci | awk -F': ' '/VGA compatible controller|3D controller/{if (out != "") out=out ";"; out=out $2} END{print out}')"
ROOT_FS="$(findmnt -n -o FSTYPE /)"
ROOT_SOURCE="$(findmnt -n -o SOURCE /)"
DEFAULT_ROUTE="$(ip route show default | awk 'NR==1{print "default-route"; exit}')"
PACMAN_VERSION="$(pacman --version 2>&1 | awk '{for (i=1; i<NF; i++) if ($i == "Pacman" && $(i+1) ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/) {print $(i+1); exit}}')"
RELEASE_REF="$(tr -d '[:space:]' < "$ROOT/release.ref")"
MEMORY_KB="$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo)"
[[ -r /etc/resolv.conf ]] || error '/etc/resolv.conf is unavailable.'
DNS_NAMESERVERS="$(awk '$1 == "nameserver" {if (out != "") out=";"; out=out $2} END{print out}' /etc/resolv.conf)"

for pair in \
  "cpu=$CPU_MODEL" \
  "gpu=$GPU_INFO" \
  "filesystem=$ROOT_FS" \
  "root_storage=$ROOT_SOURCE" \
  "network=$DEFAULT_ROUTE" \
  "dns_nameservers=$DNS_NAMESERVERS" \
  "package_manager=$PACMAN_VERSION" \
  "memory_kb=$MEMORY_KB" \
  "release_ref=$RELEASE_REF"; do
  key="${pair%%=*}"
  value="${pair#*=}"
  [[ -n "$value" ]] || error "Required O.M.A. evidence field is empty: $key"
done

[[ "$PACMAN_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || error "Invalid pacman version evidence: $PACMAN_VERSION"
[[ "$RELEASE_REF" =~ ^[0-9a-fA-F]{40}$ ]] || error "Invalid release reference: $RELEASE_REF"

EVIDENCE="$EVIDENCE_DIR/oma-$TIMESTAMP.txt"
{
  printf 'mode=%s\n' "${MODE#--}"
  printf 'timestamp=%s\n' "$TIMESTAMP"
  printf 'hostname=%s\n' "$(uname -n)"
  printf 'distribution=%s\n' "${PRETTY_NAME:-${ID:-unknown}}"
  printf 'arch_family=true\n'
  printf 'cpu=%s\n' "$CPU_MODEL"
  printf 'gpu=%s\n' "$GPU_INFO"
  printf 'filesystem=%s\n' "$ROOT_FS"
  printf 'root_storage=%s\n' "$ROOT_SOURCE"
  printf 'network=%s\n' "$DEFAULT_ROUTE"
  printf 'dns_nameservers=%s\n' "$DNS_NAMESERVERS"
  printf 'package_manager=%s\n' "$PACMAN_VERSION"
  printf 'memory_kb=%s\n' "$MEMORY_KB"
  printf 'release_ref=%s\n' "$RELEASE_REF"
  printf '\n[required-host-capabilities]\n'
  for cmd in bash awk findmnt lspci lscpu pacman systemctl ip git date mktemp mv tr; do
    printf '%s=%s\n' "$cmd" "$(command -v "$cmd")"
  done
} > "$EVIDENCE"

if [[ "$MODE" == '--verify' ]]; then
  printf '[VERIFY] Running complete Golden Unit suite.\n'
  bash "$ROOT/tests/unit/run-golden-units.sh"
  printf '[VERIFY] Running installer dry-run.\n'
  bash "$ROOT/install.sh" --dry-run
  printf '[VERIFY] PASS: repository verification completed without system mutation.\n'
fi

sha256sum "$EVIDENCE" > "$EVIDENCE.sha256"
printf 'O.M.A. %s evidence written to %s\n' "${MODE#--}" "$EVIDENCE"
printf 'O.M.A. evidence SHA-256 written to %s.sha256\n' "$EVIDENCE"

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="$ROOT/oma-evidence"
mkdir -p "$EVIDENCE_DIR"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

error() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

CPU_MODEL="$(lscpu | awk -F: '/Model name/{gsub(/^ +/,"",$2); print $2; exit}')"
GPU_INFO="$(lspci | awk -F': ' '/VGA compatible controller|3D controller/{if (out != "") out=out ";"; out=out $2} END{print out}')"
ROOT_FS="$(findmnt -n -o FSTYPE /)"
ROOT_SOURCE="$(findmnt -n -o SOURCE /)"
DEFAULT_ROUTE="$(ip route show default | awk 'NR==1{print "default-route"; exit}')"
# Pacman's banner contains ASCII art before the version-bearing token:
#   .--.                  Pacman v7.1.0 - libalpm v16.0.1
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

{
  printf 'timestamp=%s\n' "$TIMESTAMP"
  printf 'hostname=%s\n' "$(uname -n)"
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
    command -v "$cmd" >/dev/null 2>&1 || error "Required O.M.A. command unavailable: $cmd"
    printf '%s=%s\n' "$cmd" "$(command -v "$cmd")"
  done
} > "$EVIDENCE_DIR/oma-$TIMESTAMP.txt"

printf 'O.M.A. inventory evidence written to %s\n' "$EVIDENCE_DIR/oma-$TIMESTAMP.txt"

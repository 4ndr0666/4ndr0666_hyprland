#!/usr/bin/env bash
set -euo pipefail

readonly root="$(git rev-parse --show-toplevel)"
readonly readme="$root/README.md"
readonly bootstrap_doc="$root/docs/BOOTSTRAP.md"

if grep -Fq 'raw.githubusercontent.com/4ndr0666/4ndr0666_hyprland/main/Distro-Hyprland.sh' "$readme"; then
    printf '%s\n' '[FAIL] README contains mutable main bootstrap URL' >&2
    exit 1
fi

grep -Fq 'docs/BOOTSTRAP.md' "$readme"
grep -Fq 'The bootstrap contract is intentionally immutable' "$readme"
test -f "$bootstrap_doc"
grep -Fq 'The installer must not be executed from mutable `main` content.' "$bootstrap_doc"
grep -Fq 'Distro-Hyprland.sh` is the sole bootstrap authority.' "$bootstrap_doc"
grep -Fq 'BOOTSTRAP_REF=f1468f500a14ef6ff25ff03ddee8a64044c96849' "$bootstrap_doc"

printf '%s\n' '[PASS] bootstrap documentation requires pinned procedure'

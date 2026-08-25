#!/usr/bin/env bash
set -euo pipefail

readonly readme="$(git rev-parse --show-toplevel)/README.md"
readonly bootstrap_doc="$(git rev-parse --show-toplevel)/docs/BOOTSTRAP.md"

if grep -Fq 'raw.githubusercontent.com/4ndr0666/4ndr0666_hyprland/main/Distro-Hyprland.sh' "$readme"; then
    printf '%s\n' '[FAIL] README contains mutable main bootstrap URL' >&2
    exit 1
fi

grep -Fq 'docs/BOOTSTRAP.md' "$readme"
grep -Fq 'Do not execute `Distro-Hyprland.sh` from mutable `main`.' "$readme"
test -f "$bootstrap_doc"

printf '%s\n' '[PASS] bootstrap documentation requires pinned procedure'

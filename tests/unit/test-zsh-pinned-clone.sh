#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/install-scripts/zsh.sh"

[[ -f "$FILE" ]] || { printf '[FAIL] Missing Zsh installer.\n' >&2; exit 1; }
grep -q '^#!/bin/bash$' "$FILE"
grep -Fq 'GIT_COMMAND_TIMEOUT=' "$FILE"
grep -Fq 'command -v timeout' "$FILE"
grep -Fq "trap 'rm -rf -- \"\$tmp\"' RETURN" "$FILE"
grep -Fq 'timeout --signal=TERM --kill-after=30s' "$FILE"
grep -Fq 'git clone --quiet --filter=blob:none --no-checkout' "$FILE"
grep -Fq 'git -C "$tmp" checkout --quiet --detach "$revision"' "$FILE"
grep -Fq 'actual="$(git -C "$tmp" rev-parse HEAD)"' "$FILE"
grep -Fq 'rm -rf -- "$tmp/.git"' "$FILE"
grep -Fq 'mv -- "$tmp" "$destination"' "$FILE"
grep -Fq 'trap - RETURN' "$FILE"
! grep -Fq 'git clone --quiet --filter=blob:none --no-checkout "$url" "$tmp" || true' "$FILE"
bash -n "$FILE"
printf '[PASS] Zsh dependency clones are pinned, bounded, and cleanup-safe.\n'

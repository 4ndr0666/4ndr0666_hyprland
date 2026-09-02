#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/auto-install.sh"

# The bootstrap must carry exactly one immutable 40-character commit SHA.
grep -Eq '^RELEASE_REF="[0-9a-fA-F]{40}"$' "$FILE"
grep -Fq 'git clone --no-checkout "$REPOSITORY_URL" "$Distro_DIR"' "$FILE"
grep -Fq 'git fetch --depth=1 --no-tags origin "$RELEASE_REF"' "$FILE"
grep -Fq 'git checkout --detach --force "$RELEASE_REF"' "$FILE"
grep -Fq 'git rev-parse HEAD' "$FILE"
grep -Fq 'Refusing to mutate existing installation path' "$FILE"

if grep -Eq 'git pull|git merge|git checkout main|git checkout master' "$FILE"; then
  echo 'mutable auto-installer update path detected' >&2
  exit 1
fi

if grep -Fq 'if [[ ! -d "$Distro_DIR/.git" ]]' "$FILE"; then
  echo 'existing-checkout mutation path detected' >&2
  exit 1
fi

echo 'auto-installer immutability: PASS'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

[[ ! -d "$ROOT/config/ags" ]]
! grep -R -n --exclude-dir=.git --exclude-dir=archive --exclude='test-ags-retirement-boundary.sh' 'config/ags\|enable_ags\|\.config/ags' "$ROOT" >/dev/null 2>&1
! grep -R -n --exclude-dir=.git --exclude-dir=archive 'com/github/Aylur/ags\|resource:///com/github/Aylur/ags' "$ROOT" >/dev/null 2>&1

grep -R -n --exclude-dir=.git --exclude-dir=archive 'quickshell\|qs -c\|qs' "$ROOT/config/hypr" >/dev/null 2>&1

printf '%s\n' 'AGS retirement boundary: PASS'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

[[ ! -d "$ROOT/config/ags" ]]
! grep -R -n --exclude-dir=.git --exclude-dir=archive 'command -v ags\|ags -q\|ags -t\|ags &' "$ROOT" >/dev/null 2>&1
! grep -R -n --exclude-dir=.git --exclude-dir=archive 'com/github/Aylur/ags\|resource:///com/github/Aylur/ags' "$ROOT" >/dev/null 2>&1

grep -R -n --exclude-dir=.git --exclude-dir=archive 'quickshell\|qs -c\|qs' "$ROOT/config/hypr" >/dev/null 2>&1

grep -Fq 'WallustAwww.sh' "$ROOT/config/hypr/scripts/WallustAwww.sh"

printf '%s\n' 'AGS retirement boundary: PASS'

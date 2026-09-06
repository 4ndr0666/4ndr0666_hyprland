#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/config/hypr/UserScripts/Weather.sh"

# A failed location lookup must not fall through to an empty or placeholder city.
! grep -Fq 'SET YOUR MANUAL CITY HERE' "$FILE"
! grep -Eq 'city=[[:space:]]*"[[:space:]]*"[[:space:]]*#' "$FILE"
grep -Fq 'WEATHER_CITY' "$FILE"
grep -Fq 'Unable to determine weather city' "$FILE"
grep -Fq 'Using configured weather city' "$FILE"

printf '[PASS] weather fallback requires an explicit WEATHER_CITY configuration.\n'

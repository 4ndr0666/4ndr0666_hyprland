#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" > "$CAPTURE"\nprintf "%%s\\n" "${REPLY_TEXT:-ok}"\n' > "$tmp/bin/hyprctl"
chmod +x "$tmp/bin/hyprctl"
export PATH="$tmp/bin:$PATH" HOME="$tmp/home" CAPTURE="$tmp/call"
bash "$ROOT/config/hypr/UserScripts/RainbowBorders.sh"
grep -Eq '^eval hl\.config\(.*colors = \{"rgba\([[:xdigit:]]{8}\)","rgba\([[:xdigit:]]{8}\)",\}, angle = 45' "$CAPTURE"
if REPLY_TEXT='error: rejected' bash "$ROOT/config/hypr/UserScripts/RainbowBorders.sh"; then exit 1; fi

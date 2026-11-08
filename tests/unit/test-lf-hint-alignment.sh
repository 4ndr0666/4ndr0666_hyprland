#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# The selected binding, displayed hint and clickable hint must agree.
grep -Fq 'hl.dsp.exec_cmd(term .. " -e lf")' "$ROOT/config/hypr/UserConfigs/UserKeybinds.lua"
grep -Fq '" F2" "File Manager" "LF"' "$ROOT/config/hypr/scripts/KeyHints.sh"
grep -Fq '"LF")' "$ROOT/config/hypr/scripts/KeyHints.sh"
grep -Fq 'kitty -e lf &' "$ROOT/config/hypr/scripts/KeyHints.sh"
! grep -Fq 'kitty -e yazi &' "$ROOT/config/hypr/scripts/KeyHints.sh"

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"
export CAPTURE="$tmp/launch" PATH="$tmp/bin:$PATH"
printf '#!/bin/bash\nexit 1\n' > "$tmp/bin/pidof"
printf '#!/bin/bash\nexit 0\n' > "$tmp/bin/notify-send"
printf '#!/bin/bash\nprintf "%%s\\n" "$SELECTION"\n' > "$tmp/bin/yad"
printf '#!/bin/bash\nprintf "%%s\\n" "$*" > "$CAPTURE"\n' > "$tmp/bin/kitty"
for tool in mpv wofi_media.sh 4ndr0pac; do
 printf '#!/bin/bash\nprintf "%%s\\n" "%s" > "$CAPTURE"\n' "$tool" > "$tmp/bin/$tool"
done
chmod +x "$tmp/bin/"*
for target in LF MPV wofi_media.sh 4ndr0pac; do
 export SELECTION="SUPER|Launch|$target"
 bash "$ROOT/config/hypr/scripts/KeyHints.sh"
 # Background launcher completes asynchronously; wait briefly for its capture.
 for attempt in {1..20}; do [[ -f "$CAPTURE" ]] && break; sleep 0.05; done
 [[ -f "$CAPTURE" ]]
 case "$target" in LF) grep -Fxq -- '-e lf' "$CAPTURE" ;; MPV) grep -Fxq mpv "$CAPTURE" ;; *) grep -Fxq "$target" "$CAPTURE" ;; esac
 rm -f "$CAPTURE"
done

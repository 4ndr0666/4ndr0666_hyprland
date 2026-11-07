#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/custom config" CAPTURE="$tmp/args"
cat > "$tmp/bin/alacritty" <<'STUB'
#!/bin/bash
if (($#)); then printf '%s\n' "$@" > "$CAPTURE"; else : > "$CAPTURE"; fi
STUB
chmod +x "$tmp/bin/alacritty"
export PATH="$tmp/bin:$PATH"
script="$ROOT/config/hypr/UserScripts/alacritty4ndr0666"
bash "$script"
[[ ! -s "$CAPTURE" ]]
bash "$script" -f -e printf 'argument with spaces'
grep -Fxq 'alacritty-float,alacritty-float' "$CAPTURE"
grep -Fxq 'argument with spaces' "$CAPTURE"
mkdir -p "$XDG_CONFIG_HOME/alacritty"
printf '# personal\n' > "$XDG_CONFIG_HOME/alacritty/alacritty.toml"
bash "$script" -F -e test
grep -Fxq "$XDG_CONFIG_HOME/alacritty/alacritty.toml" "$CAPTURE"
grep -Fxq 'window.startup_mode="Fullscreen"' "$CAPTURE"
grep -Fxq 'alacritty-fullscreen,alacritty-fullscreen' "$CAPTURE"

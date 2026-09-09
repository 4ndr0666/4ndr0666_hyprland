#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-waybar-test.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
mkdir -p "$HOME/.config/waybar/configs" "$HOME/.config/waybar/style"
printf '%s\n' 'desktop-config' >"$HOME/.config/waybar/configs/[TOP] Default"
printf '%s\n' 'laptop-config' >"$HOME/.config/waybar/configs/[TOP] Default Laptop"
printf '%s\n' 'old-config' >"$HOME/.config/waybar/configs/[TOP] Default (old v1)"
printf '%s\n' 'user-config' >"$HOME/.config/waybar/config"
printf '%s\n' 'user-style' >"$HOME/.config/waybar/style.css"
printf '%s\n' 'neon-style' >"$HOME/.config/waybar/style/[Extra] Neon Circuit.css"

source "$ROOT/scripts/lib_waybar.sh"

[[ -f "$HOME/.config/waybar/config" ]]
[[ -f "$HOME/.config/waybar/style.css" ]]

SHIM_BIN="$TEST_ROOT/bin"
mkdir -p "$SHIM_BIN"
printf '%s\n' 0 >"$TEST_ROOT/ln.calls"
cat >"$SHIM_BIN/ln" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
calls="$(cat "$TEST_ROOT/ln.calls")"
((calls += 1))
printf '%s\n' "$calls" >"$TEST_ROOT/ln.calls"
if ((calls == 2)); then
  exit 1
fi
exec /usr/bin/ln "$@"
EOF
chmod +x "$SHIM_BIN/ln"
ORIGINAL_PATH="$PATH"
export TEST_ROOT
export PATH="$SHIM_BIN:$PATH"

if waybar_link_transaction desktop /dev/null; then
  printf '%s\n' '[FAIL] Waybar transaction unexpectedly succeeded during injected link failure.' >&2
  exit 1
fi

[[ -f "$HOME/.config/waybar/config" ]]
[[ "$(cat "$HOME/.config/waybar/config")" == 'user-config' ]]
[[ -f "$HOME/.config/waybar/style.css" ]]
[[ "$(cat "$HOME/.config/waybar/style.css")" == 'user-style' ]]
[[ -f "$HOME/.config/waybar/configs/[TOP] Default (old v1)" ]]
[[ "$(cat "$HOME/.config/waybar/configs/[TOP] Default (old v1)")" == 'old-config' ]]

export PATH="$ORIGINAL_PATH"
waybar_link_transaction desktop /dev/null

printf '%s\n' '[TRACE] committed Waybar state:'
ls -la "$HOME/.config/waybar"
ls -la "$HOME/.config/waybar/configs"
readlink "$HOME/.config/waybar/config" || true
readlink "$HOME/.config/waybar/style.css" || true

[[ -L "$HOME/.config/waybar/config" ]]
[[ "$(readlink "$HOME/.config/waybar/config")" == "$HOME/.config/waybar/configs/[TOP] Default" ]]
[[ -L "$HOME/.config/waybar/style.css" ]]
[[ "$(readlink "$HOME/.config/waybar/style.css")" == 'style/[Extra] Neon Circuit.css' ]]
[[ ! -e "$HOME/.config/waybar/configs/[TOP] Default Laptop" ]]
[[ ! -e "$HOME/.config/waybar/configs/[TOP] Default (old v1)" ]]

printf '%s\n' '[PASS] Waybar link transaction preserves prior state on failure and commits on success.'

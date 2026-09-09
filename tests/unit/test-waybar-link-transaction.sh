#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-waybar-test.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
mkdir -p "$HOME/.config/waybar/configs" "$HOME/.config/waybar/style"
mkdir -p "$ROOT/config/waybar" "$ROOT/config/waybar/style"
printf '%s\n' 'desktop-config' >"$HOME/.config/waybar/configs/[TOP] Default"
printf '%s\n' 'laptop-config' >"$HOME/.config/waybar/configs/[TOP] Default Laptop"
printf '%s\n' 'old-config' >"$HOME/.config/waybar/configs/[TOP] Default (old v1)"
printf '%s\n' 'user-config' >"$HOME/.config/waybar/config"
printf '%s\n' 'user-style' >"$HOME/.config/waybar/style.css"
printf '%s\n' 'neon-style' >"$HOME/.config/waybar/style/[Extra] Neon Circuit.css"

source "$ROOT/scripts/lib_waybar.sh"

[[ -f "$HOME/.config/waybar/config" ]]
[[ -f "$HOME/.config/waybar/style.css" ]]

ln() {
  command /usr/bin/ln "$@"
  if [[ "$1" == "-sfn" ]]; then
    return 1
  fi
}

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

unset -f ln
waybar_link_transaction desktop /dev/null
[[ -L "$HOME/.config/waybar/config" ]]
[[ "$(readlink "$HOME/.config/waybar/config")" == "$HOME/.config/waybar/configs/[TOP] Default" ]]
[[ -L "$HOME/.config/waybar/style.css" ]]
[[ "$(readlink "$HOME/.config/waybar/style.css")" == 'style/[Extra] Neon Circuit.css' ]]
[[ ! -e "$HOME/.config/waybar/configs/[TOP] Default Laptop" ]]
[[ ! -e "$HOME/.config/waybar/configs/[TOP] Default (old v1)" ]]

printf '%s\n' '[PASS] Waybar link transaction preserves prior state on failure and commits on success.'

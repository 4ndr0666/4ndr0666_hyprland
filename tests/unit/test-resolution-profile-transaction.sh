#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/scripts/lib_resolution.sh"
[[ -f "$HELPER" ]] || { printf '[FAIL] Missing resolution helper.\n' >&2; exit 1; }
bash -n "$HELPER"

TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-resolution-test.XXXXXX")"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-resolution-tmp.XXXXXX")"
cleanup() {
  local rc=$?
  rm -rf -- "$TEST_HOME" "$TEST_TMP"
  return "$rc"
}
trap cleanup EXIT INT TERM HUP

export HOME="$TEST_HOME"
export TMPDIR="$TEST_TMP"
export LOG="$TEST_HOME/resolution.log"
mkdir -p "$HOME/.config/kitty" "$HOME/.config/hypr" "$HOME/.config/rofi"

cat >"$HOME/.config/kitty/kitty.conf" <<'EOF'
font_size 16.0
EOF
cat >"$HOME/.config/hypr/hyprlock.conf" <<'EOF'
old-lock
EOF
cat >"$HOME/.config/hypr/hyprlock-1080p.conf" <<'EOF'
1080-lock
EOF
cat >"$HOME/.config/hypr/hyprlock-2k.conf" <<'EOF'
existing-2k
EOF
cat >"$HOME/.config/rofi/0-shared-fonts.rasi" <<'EOF'
element-text {
  font: "JetBrainsMono Nerd Font SemiBold 13"
}
configuration {
  font: "JetBrainsMono Nerd Font SemiBold 15"
}
EOF

cp -a -- "$HOME/.config/kitty/kitty.conf" "$TEST_HOME/kitty.before"
cp -a -- "$HOME/.config/hypr/hyprlock.conf" "$TEST_HOME/lock.before"
cp -a -- "$HOME/.config/hypr/hyprlock-1080p.conf" "$TEST_HOME/lock1080.before"
cp -a -- "$HOME/.config/hypr/hyprlock-2k.conf" "$TEST_HOME/lock2k.before"
cp -a -- "$HOME/.config/rofi/0-shared-fonts.rasi" "$TEST_HOME/rofi.before"

# An occupied destination forces failure after the Kitty mutation. The
# component transaction must restore every prior target, not just the failed step.
source "$HELPER"
if apply_resolution_profile '< 1440p'; then
  printf '[FAIL] Expected occupied hyprlock-2k destination to fail the transaction.\n' >&2
  exit 1
fi
cmp -s "$TEST_HOME/kitty.before" "$HOME/.config/kitty/kitty.conf"
cmp -s "$TEST_HOME/lock.before" "$HOME/.config/hypr/hyprlock.conf"
cmp -s "$TEST_HOME/lock1080.before" "$HOME/.config/hypr/hyprlock-1080p.conf"
cmp -s "$TEST_HOME/lock2k.before" "$HOME/.config/hypr/hyprlock-2k.conf"
cmp -s "$TEST_HOME/rofi.before" "$HOME/.config/rofi/0-shared-fonts.rasi"

rm -f -- "$HOME/.config/hypr/hyprlock-2k.conf"
apply_resolution_profile '< 1440p'

grep -Fq 'font_size 14.0' "$HOME/.config/kitty/kitty.conf"
grep -Fq '1080-lock' "$HOME/.config/hypr/hyprlock.conf"
grep -Fq 'old-lock' "$HOME/.config/hypr/hyprlock-2k.conf"
grep -Fq 'SemiBold 11' "$HOME/.config/rofi/0-shared-fonts.rasi"
grep -Fq 'SemiBold 13' "$HOME/.config/rofi/0-shared-fonts.rasi"

if find "$TEST_TMP" -mindepth 1 -maxdepth 1 -name '4ndr0666-resolution.*' -print -quit | grep -q .; then
  printf '[FAIL] Resolution transaction state leaked after completion.\n' >&2
  exit 1
fi

printf '[PASS] resolution profile is an isolated reversible transaction boundary.\n'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/config/hypr/UserScripts/RainbowBorders.sh"
BACKUP="$ROOT/config/hypr/UserScripts/RainbowBorders.bak.sh"
QUICK_SETTINGS="$ROOT/config/hypr/scripts/4ndr0666_Quick_Settings.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/gup-rainbow-borders.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[[ -x "$SCRIPT" ]] || fail "functional RainbowBorders.sh must exist and be executable"
[[ -x "$BACKUP" ]] || fail "historical backup/template path unexpectedly disappeared"
! grep -Fq 'mv "$disabled_bak_sh" "$rainbow_script"' "$QUICK_SETTINGS" || fail "Quick Settings can still promote the .bak.sh template to active implementation"

mkdir -p "$TMP/bin" "$TMP/home/.config/hypr/wallust"
cat >"$TMP/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >>"$RAINBOW_HYPRCTL_LOG"
STUB
chmod +x "$TMP/bin/hyprctl"
cat >"$TMP/home/.config/hypr/wallust/wallust-hyprland.conf" <<'WALLUST'
$color0 = rgb(112233)
$color1 = rgb(AABBCC)
WALLUST

export PATH="$TMP/bin:$PATH"
export HOME="$TMP/home"
export RAINBOW_HYPRCTL_LOG="$TMP/hyprctl.log"

for mode in wallust_random rainbow gradient_flow; do
  : >"$RAINBOW_HYPRCTL_LOG"
  cp "$SCRIPT" "$TMP/RainbowBorders-$mode.sh"
  sed -i 's/^EFFECT_TYPE=.*/EFFECT_TYPE="'"$mode"'"/' "$TMP/RainbowBorders-$mode.sh"
  bash "$TMP/RainbowBorders-$mode.sh" || fail "$mode mode failed"
  [[ "$(wc -l <"$RAINBOW_HYPRCTL_LOG")" -eq 1 ]] || fail "$mode must issue exactly one compositor update"
  grep -Fq 'dispatch hl.config(' "$RAINBOW_HYPRCTL_LOG" || fail "$mode did not use the Hyprland Lua IPC configuration dispatcher"
  grep -Fq 'col.active_border' "$RAINBOW_HYPRCTL_LOG" || fail "$mode did not configure active borders"
  ! grep -Fq 'keyword general:col.active_border' "$RAINBOW_HYPRCTL_LOG" || fail "$mode used deprecated keyword IPC"
done

: >"$RAINBOW_HYPRCTL_LOG"
cp "$SCRIPT" "$TMP/RainbowBorders-unsupported.sh"
sed -i 's/^EFFECT_TYPE=.*/EFFECT_TYPE="unsupported"/' "$TMP/RainbowBorders-unsupported.sh"
if bash "$TMP/RainbowBorders-unsupported.sh" >/dev/null 2>&1; then
  fail "unsupported mode must fail closed"
fi
[[ ! -s "$RAINBOW_HYPRCTL_LOG" ]] || fail "unsupported mode changed compositor state"

printf '%s\n' '[PASS] Rainbow Borders modes execute Lua IPC and inert backup cannot be restored'

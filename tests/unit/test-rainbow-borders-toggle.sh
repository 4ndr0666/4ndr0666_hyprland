#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/config/hypr/scripts/RainbowBordersToggle.sh"
QUICK_SETTINGS="$ROOT/config/hypr/scripts/4ndr0666_Quick_Settings.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/rainbow-toggle.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT

fail() {
    printf '[FAIL] %s\n' "$*" >&2
    exit 1
}

[[ -f "$HELPER" ]] || fail "Rainbow Borders toggle helper is missing"
bash -n "$HELPER" || fail "toggle helper has invalid Bash syntax"
bash -n "$QUICK_SETTINGS" || fail "Quick Settings has invalid Bash syntax"
grep -Fq 'bash "$toggle_script" toggle' "$QUICK_SETTINGS" || fail "Quick Settings toggle menu is not connected to the helper"
grep -Fq 'exit $?' "$QUICK_SETTINGS" || fail "Quick Settings CLI entry point masks helper failures"
! grep -Fq '$status' "$QUICK_SETTINGS" || fail "Rainbow Borders mode fallback references an undefined status variable"

export HOME="$TMP/home"
export RAINBOW_TEST_LOG="$TMP/commands.log"
mkdir -p "$HOME/.config/hypr/UserScripts" "$HOME/.config/hypr/scripts" "$TMP/bin"
export PATH="$TMP/bin:$PATH"
ACTIVE="$HOME/.config/hypr/UserScripts/RainbowBorders.sh"
DISABLED="$ACTIVE.bak"
REFRESH="$HOME/.config/hypr/scripts/Refresh.sh"

cat >"$TMP/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
printf 'hyprctl:%s\n' "$*" >>"$RAINBOW_TEST_LOG"
[[ "${RAINBOW_HYPRCTL_FAIL:-0}" != 1 ]]
STUB
cat >"$REFRESH" <<'STUB'
#!/usr/bin/env bash
printf 'refresh\n' >>"$RAINBOW_TEST_LOG"
[[ "${RAINBOW_REFRESH_FAIL:-0}" != 1 ]]
STUB
chmod +x "$TMP/bin/hyprctl" "$REFRESH"

make_active() {
    printf '#!/usr/bin/env bash\nexit 0\n' >"$ACTIVE"
    chmod +x "$ACTIVE"
}
reset_state() {
    rm -f -- "$ACTIVE" "$DISABLED"
    : >"$RAINBOW_TEST_LOG"
    unset RAINBOW_HYPRCTL_FAIL RAINBOW_REFRESH_FAIL
}

# Active -> disabled; compositor reload must succeed.
reset_state
make_active
bash "$HELPER" toggle || fail "active-to-disabled toggle failed"
[[ ! -e "$ACTIVE" && -x "$DISABLED" ]] || fail "disable did not preserve the executable as the managed disabled copy"
grep -Fq 'hyprctl:reload' "$RAINBOW_TEST_LOG" || fail "disable did not reload Hyprland"

# Disabled -> active; refresh must succeed.
reset_state
make_active
mv -- "$ACTIVE" "$DISABLED"
bash "$HELPER" toggle || fail "disabled-to-active toggle failed"
[[ -x "$ACTIVE" && ! -e "$DISABLED" ]] || fail "enable did not restore active state"
grep -Fxq 'refresh' "$RAINBOW_TEST_LOG" || fail "enable did not refresh runtime"

# Reload failure must restore active state.
reset_state
make_active
export RAINBOW_HYPRCTL_FAIL=1
if bash "$HELPER" toggle >/dev/null 2>&1; then fail "reload failure incorrectly returned success"; fi
[[ -x "$ACTIVE" && ! -e "$DISABLED" ]] || fail "reload failure did not roll back to active state"

# Refresh failure must restore disabled state.
reset_state
make_active
mv -- "$ACTIVE" "$DISABLED"
export RAINBOW_REFRESH_FAIL=1
if bash "$HELPER" toggle >/dev/null 2>&1; then fail "refresh failure incorrectly returned success"; fi
[[ ! -e "$ACTIVE" && -x "$DISABLED" ]] || fail "refresh failure did not roll back to disabled state"

# Ambiguous state must fail closed without changing either file.
reset_state
make_active
cp "$ACTIVE" "$DISABLED"
if bash "$HELPER" toggle >/dev/null 2>&1; then fail "inconsistent state incorrectly returned success"; fi
[[ -f "$ACTIVE" && -f "$DISABLED" ]] || fail "inconsistent state was mutated"

# Missing state must fail closed.
reset_state
if bash "$HELPER" toggle >/dev/null 2>&1; then fail "missing state incorrectly returned success"; fi

printf '%s\n' '[PASS] Rainbow Borders toggle connects to Quick Settings, rolls back failed transitions, and fails closed on ambiguous/missing state'

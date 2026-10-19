#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/config/hypr/scripts/Tak0-Autodispatch.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ -f "$SCRIPT" ]] || fail "autodispatch script is missing"
grep -Fq 'set -Eeuo pipefail' "$SCRIPT" || fail "autodispatch does not fail closed"
grep -Fq 'trap cleanup EXIT INT TERM' "$SCRIPT" || fail "autodispatch cleanup trap is missing"
grep -Fq 'Hyprland did not become ready within 5 seconds' "$SCRIPT" || fail "autodispatch readiness failure is not loud"
! grep -Fq 'TO-DO' "$SCRIPT" || fail "autodispatch retains unfinished TODO state"
grep -Fq '"${CMD[@]}" &' "$SCRIPT" || fail "autodispatch command boundary is not argv-safe"

printf 'PASS: autodispatch has explicit readiness, argv-safe launch, and unconditional cleanup contracts\n'

# Exercise the EXIT cleanup path with a deterministic mocked compositor. The
# mock accepts monitor readiness and the global rule, then rejects the first
# narrow rule. Cleanup must still attempt to disable both temporary rule names.
TMP="$(mktemp -d "${TMPDIR:-/tmp}/gup-autodispatch.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/script"
cp "$SCRIPT" "$TMP/script/Tak0-Autodispatch.sh"
cat >"$TMP/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >>"$AUTODISPATCH_LOG"
if [[ "${1-}" == "-j" && "${2-}" == "monitors" ]]; then
  printf '[]\n'
  exit 0
fi
if [[ "${1-}" == "dispatch" && "$*" == *'name = "tak0-autodispatch-rule-1"'* && "$*" != *'set_enabled(false)'* ]]; then
  exit 42
fi
exit 0
STUB
chmod +x "$TMP/bin/hyprctl"
export PATH="$TMP/bin:$PATH"
export AUTODISPATCH_LOG="$TMP/hyprctl.log"
if bash "$TMP/script/Tak0-Autodispatch.sh" 2 'class:^(example)$' -- /bin/true >/dev/null 2>&1; then
  fail "injected capture-rule failure must propagate as nonzero"
fi
grep -Fq 'name = "tak0-autodispatch-global"' "$AUTODISPATCH_LOG" || fail "global temporary capture rule was not installed"
grep -F 'name = "tak0-autodispatch-global"' "$AUTODISPATCH_LOG" | grep -Fq 'set_enabled(false)' || fail "global temporary rule cleanup was not attempted"
grep -Fq 'name = "tak0-autodispatch-rule-1"' "$AUTODISPATCH_LOG" || fail "narrow temporary capture rule was not attempted"
grep -F 'name = "tak0-autodispatch-rule-1"' "$AUTODISPATCH_LOG" | grep -Fq 'set_enabled(false)' || fail "narrow temporary rule cleanup was not attempted"

printf 'PASS: autodispatch cleanup is exercised against an injected compositor failure\n'

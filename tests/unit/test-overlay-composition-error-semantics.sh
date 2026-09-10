#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB_COPY="$ROOT/scripts/lib_copy.sh"
LIB_RESOLUTION="$ROOT/scripts/lib_resolution.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

bash -n "$LIB_COPY" || fail 'lib_copy.sh has invalid shell syntax'
bash -n "$LIB_RESOLUTION" || fail 'lib_resolution.sh has invalid shell syntax'

source "$LIB_COPY"
source "$LIB_RESOLUTION"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-overlay-test.XXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT

base="$tmp/base.conf"
old="$tmp/old.conf"
out="$tmp/out.conf"
disable="$tmp/disable.conf"

cat >"$base" <<'EOF'
exec-once = base-command
windowrule = float, class:^(base)$
EOF

cat >"$old" <<'EOF'
exec-once = base-command
exec-once = user-command
# exec-once = disabled-command
windowrule = float, class:^(base)$
windowrule = float, class:^(user)$
# windowrule = float, class:^(disabled)$
EOF

compose_overlay_from_backup startup "$base" "$old" "$out" "$disable"
grep -Fxq 'exec-once = user-command' "$out" || fail 'startup overlay lost user entry'
! grep -Fq 'base-command' "$out" || fail 'startup overlay retained base entry'
grep -Fxq 'disabled-command' "$disable" || fail 'startup disable entry was not preserved'

empty="$tmp/empty.conf"
empty_out="$tmp/out.empty"
empty_disable="$tmp/disable.empty"
: >"$empty"
compose_overlay_from_backup startup "$empty" "$empty" "$empty_out" "$empty_disable"
[[ ! -s "$empty_out" ]] || fail 'empty startup overlay is not empty'
[[ ! -s "$empty_disable" ]] || fail 'empty startup disable overlay is not empty'

if compose_overlay_from_backup startup "$tmp/missing-base" "$old" "$tmp/fail.out" "$tmp/fail.disable"; then
  fail 'unreadable base input was silently accepted'
fi

[[ ! -e "$tmp/fail.out" || ! -s "$tmp/fail.out" ]] || fail 'failed composition produced a non-empty output'

printf '%s\n' 'PASS: overlay composition distinguishes no-match from I/O failure.'

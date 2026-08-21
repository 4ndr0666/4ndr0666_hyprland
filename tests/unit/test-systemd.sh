#!/bin/bash
# Golden Unit Protocol: systemd state contract tests.
# A fake systemctl provides deterministic unit state without touching the host.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORE="$ROOT/install-scripts/core/systemd.sh"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

FAKEBIN="$TMPDIR/bin"
STATE="$TMPDIR/systemd.state"
MANIFEST="$TMPDIR/systemd.manifest"
mkdir -p "$FAKEBIN"
cat > "$STATE" <<'EOF'
sddm.service|loaded|disabled|inactive
lightdm.service|loaded|enabled|active
gdm.service|loaded|masked|inactive
EOF

cat > "$FAKEBIN/systemctl" <<'EOF'
#!/bin/bash
set -u
state="${FAKE_SYSTEMD_STATE:?}"

get_field() {
  local unit="$1" field="$2"
  awk -F'|' -v unit="$unit" -v field="$field" '
    $1 == unit {
      if (field == "load") print $2
      else if (field == "enabled") print $3
      else if (field == "active") print $4
    }
  ' "$state"
}

set_field() {
  local unit="$1" field="$2" value="$3"
  awk -F'|' -v OFS='|' -v unit="$unit" -v field="$field" -v value="$value" '
    $1 == unit {
      if (field == "enabled") $3=value
      else if (field == "active") $4=value
    }
    { print }
  ' "$state" > "${state}.tmp"
  mv -- "${state}.tmp" "$state"
}

unit=""
for arg in "$@"; do
  [[ "$arg" == -- ]] && continue
  unit="$arg"
done

case "${1:-}" in
  show)
    case "${3:-}" in
      --value) [[ "$(get_field "$unit" load)" == loaded ]] && printf 'loaded\n' || printf 'not-found\n' ;;
    esac
    ;;
  is-enabled)
    value="$(get_field "$unit" enabled)"
    [[ -n "$value" ]] && printf '%s\n' "$value" || exit 1
    ;;
  is-active)
    value="$(get_field "$unit" active)"
    [[ -n "$value" ]] && printf '%s\n' "$value" || exit 3
    ;;
  enable)
    set_field "$unit" enabled enabled
    ;;
  disable)
    set_field "$unit" enabled disabled
    ;;
  start)
    set_field "$unit" active active
    ;;
  stop)
    set_field "$unit" active inactive
    ;;
  mask)
    set_field "$unit" enabled masked
    ;;
esac
EOF

cat > "$FAKEBIN/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF

chmod +x "$FAKEBIN"/*
export PATH="$FAKEBIN:$PATH"
export FAKE_SYSTEMD_STATE="$STATE"
export SYSTEMD_STATE_MANIFEST="$MANIFEST"

source "$CORE"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

systemd_capture_units sddm.service lightdm.service gdm.service missing.service

grep -Fqx 'sddm.service|disabled|inactive' "$MANIFEST" || fail 'sddm pre-state not captured'
grep -Fqx 'lightdm.service|enabled|active' "$MANIFEST" || fail 'lightdm pre-state not captured'
grep -Fqx 'gdm.service|masked|inactive' "$MANIFEST" || fail 'gdm pre-state not captured'
grep -Fqx 'missing.service|absent|absent' "$MANIFEST" || fail 'absent unit state not captured'

sudo systemctl enable -- sddm.service
sudo systemctl stop -- lightdm.service
systemd_restore_units

[[ "$(systemd_unit_enabled_state sddm.service)" == disabled ]] || fail 'sddm enabled state was not restored'
[[ "$(systemd_unit_active_state lightdm.service)" == active ]] || fail 'lightdm active state was not restored'
[[ "$(systemd_unit_enabled_state gdm.service)" == masked ]] || fail 'masked state was not restored'

printf 'PASS: systemd core\n'

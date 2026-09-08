#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DETECT="$ROOT/scripts/lib_detect.sh"

[[ -f "$DETECT" ]]
grep -q '^detect_nvidia_adjust()' "$DETECT"
grep -q '^detect_vm_adjust()' "$DETECT"
grep -q '^detect_nixos_adjust()' "$DETECT"
grep -q '^detect_waybar_config()' "$DETECT"

grep -q 'hardware_info="$(lspci -k)"' "$DETECT"
grep -q 'host_info="$(hostnamectl)"' "$DETECT"
grep -q 'Unable to inspect PCI hardware' "$DETECT"
grep -q 'Unable to inspect host environment' "$DETECT"

if grep -Eq 'lspci -k.*\|.*grep.*\|.*grep' "$DETECT"; then
  printf '%s\n' '[FAIL] Nvidia detection uses an unchecked command pipeline.' >&2
  exit 1
fi

if grep -Eq 'hostnamectl.*\|.*grep' "$DETECT"; then
  printf '%s\n' '[FAIL] Host detection uses an unchecked command pipeline.' >&2
  exit 1
fi

if grep -Fq 'tee -a "$log" || true' "$DETECT"; then
  printf '%s\n' '[FAIL] Detection logging suppresses write failures.' >&2
  exit 1
fi

TMPDIR_TEST="$(mktemp -d "${TMPDIR:-/tmp}/gup-detection-test.XXXXXX")"
cleanup() {
  rm -rf -- "$TMPDIR_TEST"
}
trap cleanup EXIT

mkdir -p "$TMPDIR_TEST/bin"
cat >"$TMPDIR_TEST/bin/lspci" <<'EOF'
#!/usr/bin/env bash
exit 73
EOF
chmod +x "$TMPDIR_TEST/bin/lspci"

cat >"$TMPDIR_TEST/bin/hostnamectl" <<'EOF'
#!/usr/bin/env bash
exit 74
EOF
chmod +x "$TMPDIR_TEST/bin/hostnamectl"

PATH="$TMPDIR_TEST/bin:$PATH"
source "$DETECT"

log="$TMPDIR_TEST/detect.log"
if detect_nvidia_adjust "$log"; then
  printf '%s\n' '[FAIL] Nvidia detection accepted lspci failure.' >&2
  exit 1
else
  rc=$?
  ((rc == 73)) || { printf '%s\n' "[FAIL] Nvidia detection returned status $rc, expected 73." >&2; exit 1; }
fi

if detect_vm_adjust "$log"; then
  printf '%s\n' '[FAIL] VM detection accepted hostnamectl failure.' >&2
  exit 1
else
  rc=$?
  ((rc == 74)) || { printf '%s\n' "[FAIL] VM detection returned status $rc, expected 74." >&2; exit 1; }
fi

if detect_nixos_adjust "$log"; then
  printf '%s\n' '[FAIL] NixOS detection accepted hostnamectl failure.' >&2
  exit 1
else
  rc=$?
  ((rc == 74)) || { printf '%s\n' "[FAIL] NixOS detection returned status $rc, expected 74." >&2; exit 1; }
fi

if detect_waybar_config >/dev/null; then
  printf '%s\n' '[FAIL] Waybar detection accepted hostnamectl failure.' >&2
  exit 1
else
  rc=$?
  ((rc == 74)) || { printf '%s\n' "[FAIL] Waybar detection returned status $rc, expected 74." >&2; exit 1; }
fi

printf '%s\n' '[PASS] detection lifecycle contract'

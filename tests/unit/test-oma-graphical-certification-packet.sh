#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKET="$ROOT/tests/oma/run-graphical-certification-packet.sh"
DOC="$ROOT/docs/OMA-GRAPHICAL-CERTIFICATION-PACKET.md"

[[ -x "$PACKET" ]] || {
  printf '[FAIL] Graphical certification packet is not executable: %s\n' "$PACKET" >&2
  exit 1
}

bash -n "$PACKET"
[[ -r "$DOC" ]] || {
  printf '[FAIL] Graphical certification packet documentation is missing: %s\n' "$DOC" >&2
  exit 1
}

grep -Fq 'tests/oma/run-oma1.sh' "$PACKET"
grep -Fq 'tests/oma/run-oma2.sh" --safe' "$PACKET"
grep -Fq 'run-golden-units.sh' "$PACKET"
grep -Fq 'summary=BLOCKED' "$PACKET"
grep -Fq 'oma2=NOT_RUN' "$PACKET"
grep -Fq 'oma2_destructive=NOT_RUN' "$PACKET"
grep -Fq 'system_mutation=NONE_BY_THIS_PACKET' "$PACKET"
grep -Fq 'packet_exit()' "$PACKET"
grep -Fq 'sha256sum "$PACKET_EVIDENCE" > "$PACKET_EVIDENCE.sha256"' "$PACKET"

grep -Fq 'bash tests/oma/run-graphical-certification-packet.sh' "$DOC"
grep -Fq 'O.M.A.-1 = PASS' "$DOC"
grep -Fq 'O.M.A.-2 --safe = PASS' "$DOC"
grep -Fq 'O.M.A.-2 --destructive = NOT RUN' "$DOC"

printf '%s\n' 'PASS: graphical O.M.A. certification packet contract'

# /proc/<pid>/environ is NUL-delimited; parse it directly with Bash's NUL-aware reader.
grep -Fq "while IFS= read -r -d '' entry; do" "$PACKET"
grep -Fq 'done < "$HYPRLAND_ENV"' "$PACKET"
grep -Fq 'HYPRLAND_ENV' "$PACKET"
grep -Fq 'hyprctl instances' "$PACKET"
grep -Fq 'wl socket:' "$PACKET"
grep -Fq 'wayland_display_source=hyprctl_instances' "$PACKET"
grep -Fq 'Hyprland process WAYLAND_DISPLAY does not match Hyprland instance wl socket:' "$PACKET"
grep -Fq 'SESSION_ENV' "$PACKET"
grep -Fq 'WAYLAND_DISPLAY' "$PACKET"
grep -Fq 'XDG_RUNTIME_DIR' "$PACKET"
grep -Fq 'XDG_CURRENT_DESKTOP' "$PACKET"
grep -Fq 'XDG_SESSION_TYPE' "$PACKET"
grep -Fq 'DBUS_SESSION_BUS_ADDRESS' "$PACKET"
! grep -Fq "tr '\\u0000' '\\n'" "$PACKET"

printf '%s\n' 'PASS: graphical O.M.A. certification packet contract'

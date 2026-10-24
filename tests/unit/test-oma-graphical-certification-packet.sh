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

# Installation readiness must be a read-only gate before O.M.A.-1, and it must not
# launch daemons or weaken the existing O.M.A.-1 -> O.M.A.-2 gate.
grep -Fq 'installation_readiness=BLOCKED' "$PACKET"
grep -Fq 'installation_readiness=PASS' "$PACKET"
grep -Fq 'oma1=NOT_RUN' "$PACKET"
grep -Fq 'oma2=NOT_RUN' "$PACKET"
grep -Fq 'deployed_initializer_hook' "$PACKET"
grep -Fq 'deployed_startup_loader' "$PACKET"
grep -Fq 'for runtime_command in dbus-send dbus-launch dbus-update-activation-environment systemctl killall awww-daemon awww waybar' "$PACKET"
grep -Fq 'hyprland_portal_binary' "$PACKET"
grep -Fq 'generic_portal_binary' "$PACKET"
grep -Fq 'Installation readiness failed; O.M.A.-1 and O.M.A.-2 were not run.' "$PACKET"
! grep -Fq 'systemctl --user start' "$PACKET"
! grep -Fq 'awww-daemon --format xrgb' "$PACKET"
! grep -Fq 'waybar &' "$PACKET"

awk '
  /installation_readiness/ && !readiness { readiness=NR }
  /\[oma1\]/ && !oma1 { oma1=NR }
  END { exit !(readiness && oma1 && readiness < oma1) }
' "$PACKET"


grep -Fq 'packet_exit()' "$PACKET"
grep -Fq 'sha256sum "$PACKET_EVIDENCE" > "$PACKET_EVIDENCE.sha256"' "$PACKET"
! grep -Eq 'Evidence SHA-256: %s\.sha256.*PACKET_EVIDENCE\.sha256' "$PACKET"

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
grep -Fq 'XDG_CURRENT_DESKTOP_SOURCE=' "$PACKET"
grep -Fq 'XDG_SESSION_TYPE_SOURCE=' "$PACKET"
grep -Fq 'XDG_RUNTIME_DIR_SOURCE=' "$PACKET"
grep -Fq 'hyprland_process_identity' "$PACKET"
grep -Fq 'wayland_socket' "$PACKET"
grep -Fq 'wayland_socket_overrides_tty' "$PACKET"
! grep -Fq "tr '\\u0000' '\\n'" "$PACKET"

printf '%s\n' 'PASS: graphical O.M.A. certification packet contract'

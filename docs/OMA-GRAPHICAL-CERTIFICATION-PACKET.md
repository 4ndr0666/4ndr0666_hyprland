# Graphical O.M.A. Certification Packet

## Purpose

This packet is the single pull-and-execute procedure for the next O.M.A. certification boundary.

It is deliberately fail-closed:

1. Verify the repository is executing from the pulled revision.
2. Verify an actual Hyprland compositor process exists for the current user.
3. Reconcile compositor session context with the Hyprland instance record and its authoritative Wayland socket.
4. Run the Golden Unit gate.
5. Run O.M.A.-1.
6. Only if O.M.A.-1 passes, run O.M.A.-2 in `--safe` mode.
7. Never improvise remediation between probes.
8. Never run destructive O.M.A.-2 from this packet.

The packet itself performs no system mutation. O.M.A.-2 safe mode exercises only its existing safe lifecycle/concurrency/interruption/recovery checks.

## One-time pull

From the non-graphical environment where repository access is available:

```bash
cd /home/alarm/gup/4ndr0666_hyprland
git fetch origin main
git checkout main
git pull --ff-only origin main
git status --short --branch
```

Expected final branch line:

```text
## main...origin/main
```

A clean status is preferred. Do not reset, clean, stash, or modify the repository merely to satisfy this packet.

Confirm the packet is present:

```bash
test -x tests/oma/run-graphical-certification-packet.sh &&
printf 'PASS: graphical certification packet is present and executable\n'
```

Expected:

```text
PASS: graphical certification packet is present and executable
```

## Enter the actual Hyprland session

Start/use the normal configured Hyprland graphical session. Do not launch a second compositor merely for certification.

Once inside Hyprland, open a terminal and run exactly:

```bash
cd /home/alarm/gup/4ndr0666_hyprland
bash tests/oma/run-graphical-certification-packet.sh
```

No additional environment variables are required. The packet discovers the compositor PID and obtains the authoritative Wayland socket from `hyprctl instances`, matching the record by compositor PID. It parses the NUL-delimited `/proc/<pid>/environ` when session variables are present, but does not treat absence of inherited session markers as proof that the graphical session is invalid:

- `XDG_RUNTIME_DIR` is taken from the compositor environment when present and reconciled with the Wayland socket parent; otherwise the socket parent is used.
- `XDG_CURRENT_DESKTOP` is validated when present; if absent, the verified Hyprland process identity supplies the value `Hyprland`.
- `XDG_SESSION_TYPE` is validated when present; if absent, the verified Wayland socket supplies the value `wayland`.
- `DBUS_SESSION_BUS_ADDRESS` is retained when present but is not fabricated.

`WAYLAND_DISPLAY` is set from the matching `wl_socket` instance record and the socket is required to exist. If the compositor process itself exposes `WAYLAND_DISPLAY`, it must match that instance record; disagreement fails closed. Evidence records the source of each derived session value so inference is not presented as inherited environment evidence.

## Expected successful result

The terminal should end with:

```text
[PASS] Graphical O.M.A. certification packet completed: O.M.A.-1 + O.M.A.-2 --safe.
Packet evidence: /home/alarm/gup/4ndr0666_hyprland/oma-evidence/graphical-certification-<UTC-TIMESTAMP>.txt
Packet evidence SHA-256: /home/alarm/gup/4ndr0666_hyprland/oma-evidence/graphical-certification-<UTC-TIMESTAMP>.txt.sha256
```

The timestamp is intentionally variable. The packet records the exact repository HEAD and machine/session identity in the evidence.

A successful packet proves only the exercised O.M.A.-1 graphical baseline and O.M.A.-2 safe-mode envelope. It does not certify destructive fault injection, alternate hardware classes, power-loss behavior, or any unexercised machine equivalence class.

## Expected evidence

Inspect the packet summary:

```bash
latest="$(ls -1t oma-evidence/graphical-certification-*.txt | head -n1)"
grep -E '^(mode=|branch=|head=|hyprland_process=|wayland_display=|xdg_runtime_dir=|xdg_current_desktop=|xdg_session_type=|golden_units=|oma1=|oma2_safe=|oma2_destructive=|system_mutation=|summary=)' "$latest"
printf 'EVIDENCE=%s\n' "$latest"
printf 'EVIDENCE_SHA256=\n'
cat "$latest.sha256"
```

Successful summary must contain:

```text
hyprland_process=PASS
golden_units=PASS
oma1=PASS
oma2_safe=PASS
oma2_destructive=NOT_RUN
system_mutation=NONE_BY_THIS_PACKET
summary=PASS
```

The individual O.M.A.-1 and O.M.A.-2 evidence files created by their runners are retained alongside the packet evidence.

## Contingencies

### A. No Hyprland process

Expected packet result:

```text
[BLOCKED] No active Hyprland process was found. Enter the graphical Hyprland session and rerun this packet.
```

Do not run O.M.A.-2 manually from the TTY/SSH environment. The packet has intentionally established the graphical-session boundary as a prerequisite.

### B. Golden Units fail

Expected packet result:

```text
[FAIL] Golden Unit gate failed; O.M.A. runtime certification was not attempted.
```

Stop. Do not bypass the gate and do not run O.M.A.-2 manually.

The packet evidence contains the Golden Unit output. Return to the repository-side GUP workflow with that evidence.

### C. O.M.A.-1 fails

Expected packet result:

```text
[FAIL] O.M.A.-1 baseline failed; O.M.A.-2 was intentionally not run.
```

This is a certification boundary, not a prompt to improvise repairs. Inspect the O.M.A.-1 evidence named in the packet output.

Collect the exact probe failures without changing the machine:

```bash
latest1="$(ls -1t oma-evidence/oma1-*.txt | head -n1)"
cat "$latest1"
printf '\nSHA256:\n'
cat "$latest1.sha256"
```

Do not restart Waybar, awww, PipeWire, Hyprland, or other services solely to manufacture a PASS. A runtime failure must remain observable evidence.

### D. O.M.A.-2 safe fails

Expected packet result:

```text
[FAIL] O.M.A.-2 safe certification failed. No destructive run was attempted.
```

Collect the exact O.M.A.-2 evidence:

```bash
latest2="$(ls -1t oma-evidence/oma2-*.txt | head -n1)"
cat "$latest2"
printf '\nSHA256:\n'
cat "$latest2.sha256"
```

Do not rerun with `--destructive`. Do not bypass a failed safe-mode prerequisite.

### E. Packet command itself fails before producing packet evidence

Run only this diagnostic collection:

```bash
printf '%s\n' '=== REPOSITORY ==='
git rev-parse --show-toplevel
git rev-parse HEAD
git status --short --branch
printf '%s\n' '=== HYPRLAND ==='
pgrep -a -u "$(id -u)" -x Hyprland || true
printf '%s\n' '=== SESSION ==='
printf 'WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY:-unset}"
printf 'XDG_RUNTIME_DIR=%s\n' "${XDG_RUNTIME_DIR:-unset}"
printf 'XDG_CURRENT_DESKTOP=%s\n' "${XDG_CURRENT_DESKTOP:-unset}"
printf 'XDG_SESSION_TYPE=%s\n' "${XDG_SESSION_TYPE:-unset}"
printf '%s\n' '=== OMA EVIDENCE ==='
ls -1t oma-evidence/*.txt oma-evidence/*.sha256 2>/dev/null | head -n20 || true
```

Do not alter the repository or machine state after this diagnostic.

## Certification boundary

A successful packet establishes:

```text
GUP = GREEN
O.M.A.-1 = PASS
O.M.A.-2 --safe = PASS
O.M.A.-2 --destructive = NOT RUN
```

The next milestone after this packet is the O.M.A. destructive/recovery envelope. That is intentionally excluded from this graphical-session packet because it requires a disposable certification machine and explicit destructive authorization.

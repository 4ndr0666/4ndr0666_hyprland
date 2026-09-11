# GUP-O.M.A. Machine Setup

The O.M.A. machine workflow deliberately runs only on an explicitly provisioned Arch Linux self-hosted runner. GitHub-hosted CI cannot establish physical hardware, firmware, display, power, or driver coverage.

## Runner contract

Register each certification machine as a GitHub Actions self-hosted runner with these labels:

```text
self-hosted
linux
arch
<declared-machine-class>
```

Use one stable class label per machine equivalence class. The workflow dispatch input `runner_label` selects that class.

The runner must be a dedicated certification host or a disposable machine whose state can be restored after interruption tests. It must not be a personal workstation used concurrently for unrelated workloads.

## Required host properties

The machine must expose:

- `/etc/os-release`
- `uname`
- `lscpu`
- `lspci`
- `findmnt`
- `pacman`
- `systemctl`
- `ip`
- `git`
- Bash

The harness records the observed state rather than assuming it.

## Non-destructive verification

From the repository root:

```bash
bash tests/oma/run-oma.sh --inventory
bash tests/oma/run-oma.sh --verify
```

`--verify` runs the complete GUP suite and the installer dry-run before recording machine evidence. It does not perform package installation, configuration deployment, service mutation, or fault injection.

Evidence is written under `oma-evidence/` and is also uploaded by the O.M.A. workflow.

## Dispatch sequence

1. Provision or restore a machine belonging to a declared equivalence class.
2. Register the runner with labels `self-hosted`, `linux`, `arch`, and the exact class label.
3. Dispatch **GUP-O.M.A. Machine Assurance** with that label and `verify` mode.
4. Retain the resulting evidence artifact.
5. Repeat for every declared class.
6. Only after matrix completion provision a dedicated recovery machine for destructive interruption and rollback testing.

## Destructive certification boundary

The repository workflow intentionally does not perform destructive fault injection automatically. Power-loss, package-transaction interruption, filesystem interruption, and rollback testing require a disposable recovery machine and explicit operator control.

A machine evidence report records this boundary as `NOT-EXERCISED`; that state is never interpreted as a pass.

## Certification consequence

One runner does not certify the machine universe. O.M.A.-1 requires every declared equivalence class to have corresponding evidence. O.M.A.-2 additionally requires adversarial interruption, recovery, lifecycle, and concurrency evidence. O.M.A.-3 requires independent reproduction. O.M.A.-4 requires all preceding gates, retained evidence, no unresolved CRITICAL/HIGH defects, and tested unsupported-state fail-closed behavior.

# GUP-O.M.A. — Omnipresent Machine Assurance Protocol

## Purpose

GUP-O.M.A. is the second-level certification layer applied after the Golden Unit Protocol (GUP). GUP proves repository-level correctness; O.M.A. proves behavior across an explicitly declared Arch Linux machine support envelope.

A literal guarantee of defect-free behavior on every physically possible Arch Linux machine is not provable because the hardware, firmware, kernel, package, and environment state space is unbounded and continuously changing. O.M.A. therefore certifies the strongest reproducible claim: no defect was observed within the complete declared and exercised support envelope, while tested unsupported states fail explicitly and safely.

## Execution Doctrine

1. GUP must be GREEN before O.M.A. starts.
2. Use Blind Execution and EAFP: execute, observe, classify, recover, verify.
3. Never mask relevant failures with unconditional success, swallowed rollback errors, ignored cleanup errors, or synthetic mock success.
4. Every mutation must be atomic or explicitly recoverable.
5. Every supported operation must converge under repeated execution.
6. No finite test count is represented as proof of infinity.

## Support Envelope

Version a machine manifest covering every supported equivalence class:

- CPU architecture and generations
- GPU vendor, driver, and topology
- kernel families and firmware classes
- boot mode
- root/home filesystem and storage classes
- RAM/resource boundaries
- single/multi-display and resolution/refresh classes
- Wayland compositor/session and X11 compatibility where claimed
- systemd user/system state
- network and DNS states
- locale/timezone/environment
- package database states
- privilege and home-directory states
- power/suspend states where supported

Unsupported dimensions must be proven to fail closed without unintended mutation.

## Golden Machine Set

Maintain independently provisioned machines representing the declared equivalence classes. Physical hardware is required for hardware-specific claims that virtualization cannot faithfully expose, including physical GPU/driver, firmware, display, and power behavior.

## Required Test Matrix

### Kernel/Firmware

For each supported kernel and firmware class:

```text
clean boot -> configured boot -> install/update -> reboot
-> complete runtime path -> suspend/resume where supported
-> revert -> reboot -> recovery verification
```

### Drivers

For each supported driver path:

```text
cold boot -> login -> initialize -> exercise capability
-> restart relevant service -> logout/login -> reboot -> repeat
```

Exercise expected capability presence and explicit capability absence.

### Display/Session

Exercise single/multi-monitor, mixed resolution/refresh, hotplug/removal, compositor restart, logout/login, cold boot, and warm restart. Verify compositor, panels, notifications, wallpaper, keybindings, session targeting, stale-process absence, stale-lock absence, and configuration preservation.

### Installer Fault Injection

Inject controlled failure at dependency resolution, package installation, file creation/replacement, directory replacement, service enablement/start, configuration generation, post-install hooks, and final commit.

For each failure:

```text
failure -> non-zero exit -> abort -> rollback -> verify rollback
-> verify zero orphan state -> rerun -> successful convergence
```

### Power-Loss Simulation

Terminate at every persistent commit boundary. After reboot, the persistent state must be a valid pre-state or valid post-state. A partially committed third state is a defect.

### Network/Package/Environment Adversarial Testing

Exercise repository outage, DNS failure, resets, slow/empty/malformed responses, stale package state, conflicts, missing optional dependencies, minimal PATH, Unicode and space-containing paths, malformed/read-only configuration, and inaccessible directories. Unsupported conditions must fail explicitly without corruption.

### Lifecycle/Concurrency/Recovery

For long-running components exercise start/restart/stop/logout/login/reboot cycles and check for orphan processes, stale PID files, sockets, locks, temporary files, and duplicate daemons/handlers. Concurrent operations must serialize safely, reject conflicts deterministically, or commute safely. Every supported failure path must converge back to a valid state.

## Evidence

Retain the machine manifest, kernel/firmware/driver identity, package/repository state, relevant environment, test sequence, injected faults, exit statuses, logs, persistent-state snapshots, rollback results, repetition counts, and final verification.

A result that cannot be reproduced from its evidence is not a certification result.

## Certification Levels

- **O.M.A.-0:** support envelope declared and versioned.
- **O.M.A.-1:** all declared machine equivalence classes pass the matrix.
- **O.M.A.-2:** O.M.A.-1 plus fault injection, interruption, recovery, concurrency, and lifecycle testing.
- **O.M.A.-3:** O.M.A.-2 reproduced on independently provisioned machines/runs.
- **O.M.A.-4:** O.M.A.-3 passes, evidence is retained, no unresolved CRITICAL/HIGH defects exist, and tested unsupported states fail closed.

O.M.A.-4 is the highest defensible assurance level within the declared support envelope.

## Defect Rules

CRITICAL: data loss, corruption, feature loss, unrecoverable installation, incomplete rollback, false/silent success, security-boundary violation, destructive machine-state behavior, or certified-baseline regression.

HIGH: lifecycle leak, non-idempotent mutation, reproducible race, unintended mutation in unsupported state, recovery failure, or deterministic hardware-specific malfunction.

Environmental failure is acceptable only when it is outside the contract, detected, explicit, non-destructive, observable, and documented.

## Certification Invalidation

Material changes to supported hardware, kernel/driver architecture, firmware requirements, package/repository architecture, compositor/session architecture, installer transaction model, security boundaries, external interfaces, or the support envelope require re-certification.

## Prime Directive

> **Never certify what was not defined, exercised, observed, recovered, and reproduced.**

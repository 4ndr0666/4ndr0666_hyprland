<p align="center">
  <a href="banner.jpeg"><img src="banner.jpeg" alt="4ndr0666-Hyprland Banner"></a>
</p>

<h1 align="center">4NDR0666OS Hyprland</h1>
<p align="center">Arch Linux Hyprland environment, configuration, installer, and controlled upgrade system.</p>

---

## 1. Purpose

This repository is an **Arch Linux-only** Hyprland environment. It contains the compositor configuration, desktop components, runtime scripts, wallpapers, installer modules, and the deployment/upgrade orchestration used to bring an existing Arch installation to the repository's current state.

The repository supports two materially different operating scenarios:

1. **Fresh provisioning** — installing the required Arch-side packages and then deploying the environment.
2. **Established-machine update** — updating an already installed 4ndr0666 Hyprland environment while preserving user state and retaining recoverable backups.

If Arch Linux is already installed and the machine is already running, **use the established-machine update procedure in this README**. Do not treat an existing workstation as a fresh-install target merely because a newer repository revision is available.

---

## 2. Support Boundary

### Supported operating system

- **Arch Linux** only.
- systemd-based Arch installations are the intended runtime environment.
- Hyprland/Wayland is the primary desktop target.

The repository README previously described multiple Linux distributions. That is no longer the operational contract. The installer currently rejects non-Arch systems, and the production assurance process is defined around Arch Linux machine classes.

### Hardware and environment

The configuration is designed to accommodate common Arch desktop hardware and desktop-session variations, but a repository-level test pass is not equivalent to certification of every physical GPU, firmware revision, kernel, monitor topology, or package state.

For machine-level assurance, see:

- [`docs/GUP-O.M.A.-SKILL.md`](docs/GUP-O.M.A.-SKILL.md)
- [`docs/OMA-MACHINE-SETUP.md`](docs/OMA-MACHINE-SETUP.md)

O.M.A. defines the evidence-based process for expanding assurance from repository correctness to explicitly exercised Arch machine classes.

---

## 3. Before You Touch an Established Machine

An established workstation contains state that is not interchangeable with repository state. Treat an update as a controlled deployment, not as a blind overwrite.

Before proceeding:

- Ensure the machine is running Arch Linux.
- Ensure you can log into the existing graphical session normally.
- Close applications that should not be interrupted by configuration replacement.
- Ensure you have a working terminal and network connection.
- Ensure you know how to recover your previous configuration from the backup location used by the deployment workflow.
- Do not run the repository installer as root.
- Do not begin with `sudo ./install.sh`.
- Do not delete `~/.config/hypr`, `~/.config/waybar`, or other existing desktop configuration as a prerequisite for an update.
- If the machine is business-critical, establish a host-level backup/snapshot before deployment in accordance with your normal operational policy.

### Important distinction

`install.sh` and `copy.sh` have different responsibilities:

| Command | Intended use | Established machine |
| --- | --- | --- |
| `install.sh` | Package/dependency provisioning and optional system configuration | Use only when you intentionally need the provisioning path |
| `copy.sh --upgrade` | Configuration/environment upgrade | **Primary update path** |
| `copy.sh --express-upgrade` | Reduced-interaction upgrade for supported installed versions | Optional, when eligible |
| `copy.sh` | Interactive install/upgrade workflow | Use when selecting the workflow interactively |
| `uninstall.sh` | Removal of installer-owned packages | **Do not use as an update mechanism** |

The established-machine procedure below deliberately uses the configuration deployment path first.

---

## 4. Current-Tree Verification Before Deployment

The safest update begins from a known repository revision.

### 4.1 Inspect the current machine

Run:

```bash
cat /etc/os-release
uname -a
printf 'User: %s\n' "$USER"
printf 'Home: %s\n' "$HOME"
printf 'Session: %s\n' "${XDG_CURRENT_DESKTOP:-unknown}"
printf 'Wayland: %s\n' "${WAYLAND_DISPLAY:-not-set}"
```

Confirm that `/etc/os-release` identifies Arch Linux.

Check the currently installed Hyprland configuration version if present:

```bash
find "$HOME/.config/hypr" -maxdepth 1 -type f -name 'v*.*.*' -printf '%f\n' 2>/dev/null | sort -V | tail -n1
```

The update harness uses the installed dotfiles version to determine whether the express-upgrade path is supported.

### 4.2 Obtain the repository

If the repository is not already present locally:

```bash
git clone https://github.com/4ndr0666/4ndr0666_hyprland.git
cd 4ndr0666_hyprland
```

If it is already present:

```bash
cd /path/to/4ndr0666_hyprland
git status --short --branch
git remote -v
```

Replace `/path/to/4ndr0666_hyprland` with the actual repository path. Do not execute the literal placeholder command.

### 4.3 Protect local repository changes

If `git status` reports local modifications, stop and inspect them before updating the checkout:

```bash
git status --short
```

Do not overwrite local work merely to obtain the current repository revision. Commit, stash, or otherwise preserve intentional local changes according to your normal source-control procedure.

For a clean checkout, update the local view of `main`:

```bash
git fetch --prune origin main
git status --short --branch
```

Inspect the target revision before deployment:

```bash
git log -1 --oneline --decorate
```

The deployment should be performed from the reviewed checkout you intend to test.

---

## 5. Verify the Repository Before Mutation

The repository contains a non-mutating installer validation mode. Run it before changing the established workstation:

```bash
bash ./install.sh --dry-run
```

A successful dry-run verifies the installer module graph is present and that the installer modules pass shell syntax validation. It **does not emulate every package-manager, systemd, hardware, driver, or desktop-session operation** and it does not install or modify the system.

Then run the repository's Golden Unit suite:

```bash
bash ./tests/unit/run-golden-units.sh
```

Do not proceed if either validation reports failure.

The repository's CI should also be green for the revision being deployed. Local validation is still required because the live machine is the deployment target.

---

## 6. Recommended Established-Machine Update Procedure

This is the normal procedure for an already installed workstation.

### Step 1 — Confirm the machine is suitable

```bash
[[ -r /etc/os-release ]] && . /etc/os-release
printf 'OS=%s\n' "${ID:-unknown}"
printf 'Kernel=%s\n' "$(uname -r)"
printf 'User=%s\n' "$USER"
printf 'Home=%s\n' "$HOME"
```

Expected OS value:

```text
OS=arch
```

Do not continue if the machine is not Arch Linux.

### Step 2 — Confirm the existing desktop works

Before updating, establish a known-good baseline:

- Log into the existing graphical session.
- Confirm Hyprland starts.
- Confirm your terminal starts.
- Confirm Waybar starts.
- Confirm your launcher/menus start.
- Confirm notifications work.
- Confirm wallpaper handling works.
- Confirm your normal keybindings work.
- Confirm audio and other routinely used desktop services behave normally.

This baseline matters: after deployment, you need to distinguish a pre-existing machine problem from an update-induced regression.

### Step 3 — Record machine evidence

For a non-destructive O.M.A. inventory:

```bash
bash ./tests/oma/run-oma.sh --inventory
```

The inventory records the observed Arch machine environment without performing configuration deployment.

Review the generated `oma-evidence/` report and retain it with the test record if this is being performed as a formal certification run.

### Step 4 — Verify repository integrity

```bash
bash ./install.sh --dry-run
bash ./tests/unit/run-golden-units.sh
```

Both must complete successfully.

### Step 5 — Run the standard configuration upgrade

For a normal established-machine update:

```bash
./copy.sh --upgrade
```

Do **not** run this as root.

The upgrade workflow stages repository configuration data in a temporary deployment directory before applying the environment-specific operations. It also maintains deployment logging and performs backup/restore handling for supported existing configuration state.

The workflow can prompt for environment-specific choices such as layout, keyboard, editor, resolution, Waybar link management, and related configuration behavior. Read each prompt rather than assuming that an existing choice will automatically be preserved.

### Step 6 — Use express upgrade only when eligible

The express path is available only when the installed dotfiles version satisfies the repository's minimum supported version.

Check eligibility through:

```bash
./copy.sh --help
```

or allow the normal workflow to determine it.

If the installed version is eligible and you deliberately want the reduced-interaction path:

```bash
./copy.sh --express-upgrade
```

If the repository rejects express mode because the installed version is too old, use the standard upgrade path instead. Do not bypass the version gate.

### Step 7 — Review the deployment log

The deployment workflow writes its log under:

```text
~/.local/state/4ndr0666-hyprland/
```

Inspect the newest log:

```bash
ls -lt "$HOME/.local/state/4ndr0666-hyprland/"
```

Then review the relevant log file with:

```bash
less /path/to/the/newest/log
```

Use the actual path printed/listed by the previous command; do not execute `/path/to/the/newest/log` literally.

The deployment should be considered successful only when the command exits successfully **and** the resulting desktop state passes post-deployment verification.

### Step 8 — Verify the resulting configuration

Check the principal configuration roots:

```bash
ls -ld "$HOME/.config/hypr"
ls -ld "$HOME/.config/waybar"
ls -ld "$HOME/.config/rofi"
ls -ld "$HOME/.config/kitty"
```

Check for the expected runtime scripts:

```bash
find "$HOME/.config/hypr/scripts" -maxdepth 1 -type f -print 2>/dev/null | sort
find "$HOME/.config/hypr/UserScripts" -maxdepth 1 -type f -print 2>/dev/null | sort
```

Check executable permissions where applicable:

```bash
find "$HOME/.config/hypr/scripts" "$HOME/.config/hypr/UserScripts" \
  -maxdepth 1 -type f -print 2>/dev/null | while IFS= read -r file; do
    [[ -x "$file" ]] || printf '[WARN] Not executable: %s\n' "$file"
  done
```

### Step 9 — Restart/reload the graphical environment as appropriate

The deployment workflow updates configuration and runtime assets, but not every desktop component necessarily reloads all state immediately.

Prefer a controlled Hyprland reload/restart mechanism first. If a component remains on stale configuration, perform a controlled logout/login. A full reboot is appropriate when the update includes changes that require a new kernel/session/system service state or when the final verification specifically requires a cold boot.

Do not repeatedly kill arbitrary desktop processes as a substitute for understanding the component lifecycle.

### Step 10 — Exercise the desktop

Perform a functional smoke test:

- terminal launch
- application launcher
- Waybar
- notifications
- wallpaper selection/application
- workspace switching
- window focus/movement
- floating mode
- fullscreen
- configured media/audio controls
- Quickshell components if enabled
- SDDM if installed/configured
- GPU-specific behavior where applicable
- monitor profiles and multi-monitor behavior where applicable

A configuration update is not complete until the functions you depend on have been exercised.

---

## 7. What `copy.sh --upgrade` Does

`copy.sh` is the primary established-machine deployment orchestrator. It loads the component libraries, determines the selected workflow, stages repository configuration under a temporary directory, performs environment detection, applies configuration phases, manages selected user configuration restoration, handles Waybar links, manages backups, and regenerates the Wallust palette from the current wallpaper state.

The deployment workflow explicitly rejects root execution.

Important behaviors include:

- configuration staging in a temporary directory
- environment-specific adjustment before deployment
- version-aware upgrade handling
- backup/restore support
- Waybar link/layout management
- Quickshell configuration handling when Quickshell is available
- executable-bit normalization for Hyprland runtime scripts
- wallpaper synchronization into the user's Pictures directory
- Wallust regeneration from the persisted wallpaper state
- persistent deployment logging

If the workflow encounters a failure, **do not assume the machine is unchanged merely because the command failed**. Read the deployment log and inspect the resulting filesystem state before attempting a second run.

---

## 8. Fresh Installation Path

Use the fresh-install path only when you intentionally want the repository's package/dependency provisioning workflow.

### 8.1 Preflight

Perform a full Arch system update and reboot before installing:

```bash
sudo pacman -Syu
sudo reboot
```

After reboot, return to the repository checkout.

### 8.2 Run installer dry-run

```bash
bash ./install.sh --dry-run
```

### 8.3 Run installer

Run as the normal user:

```bash
./install.sh
```

The installer refuses root execution and verifies that the host is Arch Linux.

The installer establishes the base package path, verifies required package infrastructure, detects selected hardware/environment conditions, presents optional components through the interactive interface, and executes the canonical module sequence.

### 8.4 NVIDIA and related GPU options

Hardware-specific options are presented only when detection conditions warrant them. Do not manually enable a GPU path merely because the machine is capable of using a different driver stack.

If NVIDIA is detected, the installer can expose NVIDIA configuration. Nouveau blacklisting is a separate selectable option.

After any driver-level change, reboot and validate the graphical session before continuing with higher-level configuration testing.

---

## 9. Immutable Bootstrap for Remote Provisioning

For a reproducible remote bootstrap, use the reviewed commit-pinned procedure in [`docs/BOOTSTRAP.md`](docs/BOOTSTRAP.md).

The bootstrap contract is intentionally immutable: the bootstrap itself is fetched from an exact reviewed commit, then verifies the repository revision recorded in `release.ref` before invoking `install.sh`.

Current `release.ref` is:

```text
f1468f500a14ef6ff25ff03ddee8a64044c96849
```

For unattended or enterprise-controlled provisioning, do not substitute mutable `main` content for the reviewed bootstrap reference without explicitly reviewing and changing the release process.

---

## 10. Backups, Recovery, and Rollback

### 10.1 Repository rollback

If the repository revision itself must be rolled back, first identify the exact revision to test:

```bash
git log --oneline --decorate -20
```

Then move the checkout deliberately to the reviewed revision using normal Git procedures. Do not perform an uncontrolled `git reset --hard` against a checkout containing uncommitted work.

### 10.2 Configuration rollback

The deployment system maintains timestamped backup/restore state for supported configuration transitions. If an update produces an unacceptable result:

1. Stop making additional configuration changes.
2. Preserve the deployment log.
3. Identify the backup created by the deployment.
4. Determine which component introduced the regression.
5. Restore the affected state using the repository's supported restoration workflow.
6. Verify the restored desktop.
7. Record the failure before attempting another update.

Do not delete backup directories simply to make the deployment appear clean.

### 10.3 Host-level recovery

For critical workstations, repository-level rollback is not a substitute for system backup. Maintain appropriate filesystem/system snapshots or backups outside this repository according to the machine's operational requirements.

A package transaction, kernel change, firmware change, filesystem failure, or power interruption can affect state outside the repository's configuration-management boundary.

---

## 11. Handling an Interrupted Update

If the terminal closes, the machine loses power, the session crashes, or the update is otherwise interrupted:

**Do not immediately rerun the update.**

First:

```bash
git status --short --branch
ls -lt "$HOME/.local/state/4ndr0666-hyprland/" 2>/dev/null
```

Then:

1. Determine whether the machine is booting normally.
2. Determine whether the graphical session is usable.
3. Inspect the most recent deployment log.
4. Inspect affected configuration directories.
5. Determine whether a backup exists for the affected component.
6. Restore a known-good state if required.
7. Only then rerun the update.

Repeated execution is expected to converge for supported operations, but repeated execution after an unknown interrupted state should be preceded by state inspection.

---

## 12. Package and Installer Boundaries

The installer maintains an installer-owned package manifest and uses the package-management core under `install-scripts/core/packages.sh`.

The repository's uninstall operation is scoped to installer-owned package state. It is not a general Arch package purge.

Run:

```bash
./uninstall.sh
```

only when the objective is to remove packages recorded as installer-owned.

If package removal fails, the ownership manifest is retained so the operation can be retried. Do not manually delete the manifest to suppress the failure state.

---

## 13. Runtime Validation After an Update

After the desktop is operational, validate both visible behavior and process lifecycle.

### 13.1 Session state

```bash
printf 'XDG_CURRENT_DESKTOP=%s\n' "${XDG_CURRENT_DESKTOP:-}"
printf 'XDG_SESSION_TYPE=%s\n' "${XDG_SESSION_TYPE:-}"
printf 'WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY:-}"
```

### 13.2 Hyprland

Verify the compositor is running and that normal Hyprland controls work.

### 13.3 Waybar

Verify the selected Waybar layout is active and that only the expected Waybar process/layout state exists.

### 13.4 Wallpaper and Wallust

Verify the persisted wallpaper state exists and that wallpaper application and generated palette-dependent components work.

### 13.5 Keybindings

Exercise the bindings you actually use. The repository includes runtime scripts for application launching, workspace/layout operations, wallpaper handling, Waybar behavior, audio visualization, and other desktop functions.

### 13.6 Lifecycle

For components that run as persistent processes, test:

```text
start -> operate -> reload/restart -> operate -> logout/login -> operate -> reboot -> operate
```

Look specifically for:

- orphaned processes
- duplicate daemons
- stale PID files
- stale sockets
- stale locks
- leftover temporary files
- configuration that only works after a second restart

---

## 14. Display, GPU, and Multi-Monitor Validation

The repository is intended for real Arch hardware, so graphical validation should include the machine's actual display topology.

At minimum, verify:

- single-monitor operation
- each configured resolution/refresh mode you depend on
- multi-monitor operation if applicable
- monitor hotplug if applicable
- compositor restart
- logout/login
- cold reboot
- GPU-specific behavior
- wallpaper placement
- Waybar placement
- keybinding/session targeting

For NVIDIA systems, validate the actual driver/session combination rather than assuming detection alone proves correctness.

For a formal O.M.A. run, capture the machine inventory and execute the declared matrix rather than relying on a single smoke test.

---

## 15. Network and Package-State Considerations

The repository's deployment process depends on the machine being capable of obtaining required package/configuration resources when those operations are invoked.

Before an update that may install or change packages:

```bash
ip route
pacman --version
```

If package operations fail:

- preserve the error output
- determine whether the failure is network, repository, package database, dependency, or permission related
- do not convert the failure into an apparent successful deployment
- do not repeatedly retry without understanding the failure state

For formal assurance, O.M.A. requires adversarial network/package-state testing and explicit evidence rather than assumptions.

---

## 16. User Configuration and Local Overrides

The repository contains both baseline configuration and user-managed state. Existing-machine updates therefore require deliberate handling of local customization.

Before deployment, identify important local modifications in:

```text
~/.config/hypr/
~/.config/waybar/
~/.config/kitty/
~/.config/rofi/
~/.config/quickshell/
```

The exact set of managed components can evolve with the repository. Do not assume every file under `~/.config` is repository-owned.

If a local customization is operationally important, preserve it independently before the update. A backup produced by the deployment workflow is a recovery mechanism, not a substitute for maintaining intentional source-controlled configuration.

---

## 17. O.M.A. Machine Assurance

GUP validates repository-level correctness. GUP-O.M.A. extends the assurance boundary to actual Arch Linux machines.

The canonical O.M.A. specification is [`docs/GUP-O.M.A.-SKILL.md`](docs/GUP-O.M.A.-SKILL.md).

The machine setup contract is [`docs/OMA-MACHINE-SETUP.md`](docs/OMA-MACHINE-SETUP.md).

The executable evidence harness is:

```bash
bash ./tests/oma/run-oma.sh --inventory
bash ./tests/oma/run-oma.sh --verify
```

### O.M.A. levels

| Level | Meaning |
| --- | --- |
| O.M.A.-0 | Support envelope declared and versioned |
| O.M.A.-1 | Declared Arch machine equivalence classes pass the matrix |
| O.M.A.-2 | Matrix plus fault injection, interruption, recovery, lifecycle, and concurrency testing |
| O.M.A.-3 | O.M.A.-2 independently reproduced |
| O.M.A.-4 | Highest defensible assurance within the declared support envelope |

A machine inventory is evidence. It is not, by itself, certification.

Destructive interruption and recovery testing intentionally require a dedicated/disposable recovery machine. Do not perform destructive fault injection on a workstation whose data cannot be safely restored.

---

## 18. Formal Update Procedure

For enterprise-controlled or repeatable workstation updates, use this sequence as the operational checklist:

```text
1. Identify target Arch machine.
2. Confirm machine backup/recovery capability.
3. Confirm graphical session is healthy.
4. Record current repository and machine state.
5. Preserve intentional local repository changes.
6. Obtain the reviewed repository revision.
7. Run install.sh --dry-run.
8. Run the Golden Unit suite.
9. Capture O.M.A. machine inventory when evidence is required.
10. Run copy.sh --upgrade.
11. Preserve and review the deployment log.
12. Validate configuration paths and permissions.
13. Reload/restart the affected graphical components.
14. Exercise the required desktop functions.
15. Test logout/login and reboot when appropriate.
16. Compare the post-update machine against the pre-update baseline.
17. Retain evidence and logs.
18. Record defects before making further changes.
```

Do not skip directly from repository checkout to blind deployment on a production workstation.

---

## 19. Change-Control Guidance

For managed fleets or enterprise environments, treat a repository revision as a deployment artifact.

Record at minimum:

- repository URL
- deployed commit SHA
- deployment date/time
- target machine class
- kernel version
- GPU/driver state
- display/session topology
- installed dotfiles version before update
- selected deployment mode
- deployment log
- test results
- post-update verification result
- rollback result if rollback was required

A material change to installer logic, package architecture, compositor/session architecture, runtime lifecycle, driver handling, transaction semantics, or supported machine envelope should trigger the relevant GUP/O.M.A. revalidation.

---

## 20. Troubleshooting Rules

### The update exits non-zero

Do not suppress the error and do not assume success.

1. Preserve the terminal output.
2. Read the deployment log.
3. Identify the failing component.
4. Inspect persistent state.
5. Determine whether rollback is required.
6. Reproduce only after the failure state is understood.

### The desktop starts but a component is broken

Classify the failure by component:

- Hyprland/compositor
- Waybar
- launcher/rofi
- terminal
- wallpaper/Wallust
- notifications
- Quickshell
- audio
- SDDM/login manager
- GPU/driver
- monitor configuration
- keybinding/runtime script

Test the affected component's lifecycle independently before changing unrelated configuration.

### The machine no longer reaches a graphical session

Use a TTY or recovery path, preserve logs, and restore the known-good configuration state before experimenting further. If the failure is kernel/driver/system-service related, repository-level configuration rollback may not be sufficient; use the host's established Arch recovery procedure.

### A second update appears to fix the first update

Treat this as a defect signal, not proof of success. A supported deployment should converge under repeated execution without requiring an unexplained second pass.

---

## 21. Repository Layout

```text
.
├── assets/                       # Shared visual and desktop assets
├── config/                       # Deployed desktop configuration
│   ├── btop/
│   ├── cava/
│   ├── fastfetch/
│   ├── ghostty/
│   ├── hypr/
│   ├── kitty/
│   ├── quickshell/
│   ├── rofi/
│   ├── swaync/
│   ├── wallust/
│   └── waybar/
├── install-scripts/              # Arch package/system provisioning modules
├── scripts/                      # Deployment libraries and orchestration helpers
├── tests/
│   ├── unit/                     # Golden Unit regression tests
│   └── oma/                      # Machine evidence and O.M.A. harness
├── docs/
│   ├── BOOTSTRAP.md              # Immutable bootstrap procedure
│   ├── GUP-O.M.A.-SKILL.md       # Machine assurance protocol
│   └── OMA-MACHINE-SETUP.md      # Self-hosted machine contract
├── copy.sh                       # Established-machine configuration deployment
├── install.sh                    # Arch provisioning installer
├── uninstall.sh                  # Installer-owned package removal
└── release.ref                   # Reviewed release revision for bootstrap
```

The tree may evolve. Treat the executable scripts and canonical documentation in the current repository revision as authoritative.

---

## 22. Key Runtime Functions

The default environment provides bindings for common desktop operations. The exact active binding set should be verified against the current deployed configuration rather than assumed from documentation.

Examples include:

| Binding | Function |
| --- | --- |
| `SUPER + Return` | Terminal |
| `SUPER + D` | Application launcher |
| `SUPER + Q` | Close active window |
| `SUPER + X` | Session/logout interface |
| `SUPER + W` | Wallpaper orchestration |
| `SUPER + A` | Overview/workspace interface |
| `SUPER + SPACE` | Toggle floating state |
| `SUPER + Shift + F` | Fullscreen |
| `SUPER + Alt + R` | Runtime/layout reload |

Bindings can depend on the active configuration and installed components. Validate them on the target machine after every material configuration update.

---

## 23. Operational Principles

This project follows several non-negotiable deployment principles:

1. **Arch is the target platform.**
2. **Established-machine updates are distinct from fresh installation.**
3. **Never run the user-space deployment as root.**
4. **Validate before mutating.**
5. **Do not hide failures.**
6. **Preserve recoverable state before destructive transitions.**
7. **Treat interrupted transactions as unknown state until verified.**
8. **Require repeated execution to converge.**
9. **Test the actual machine, not merely the repository.**
10. **Never claim hardware assurance that was not exercised and evidenced.**

---

## 24. Current-State Certification Workflow

For the current repository point on an already installed Arch machine, the recommended sequence is:

```bash
cd /path/to/4ndr0666_hyprland

git status --short --branch
git log -1 --oneline --decorate

bash ./install.sh --dry-run
bash ./tests/unit/run-golden-units.sh
bash ./tests/oma/run-oma.sh --inventory

./copy.sh --upgrade
```

After the upgrade, perform the runtime validation in this README and, when formal machine evidence is desired:

```bash
bash ./tests/oma/run-oma.sh --verify
```

The O.M.A. verify mode runs the GUP suite and installer dry-run and records the observed Arch machine environment. It does not perform destructive fault injection.

---

## 25. Scope of Assurance

A successful repository test suite establishes repository-level correctness under the tested contracts. A successful live-machine update establishes that the current repository point was exercised on that particular Arch environment.

Neither result should be generalized beyond the evidence collected.

For a formal machine claim, enumerate the supported machine equivalence class, exercise it, retain the evidence, test recovery, and reproduce the result independently as required by O.M.A.

> **Never certify what was not defined, exercised, observed, recovered, and reproduced.**

---

## 26. Contributing

Changes to configuration, runtime scripts, installer modules, transaction handling, lifecycle behavior, or documentation should preserve the repository's production-readiness contracts.

Before submitting a material change:

```bash
bash ./install.sh --dry-run
bash ./tests/unit/run-golden-units.sh
```

For changes affecting machine-specific behavior, also update the applicable O.M.A. support envelope and validation evidence.

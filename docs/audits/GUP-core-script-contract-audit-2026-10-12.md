# GUP Core Script Contract Audit — 2026-10-12

## Audit identity

- Repository: `4ndr0666/4ndr0666_hyprland`
- Baseline revision: `e7361adb47c462d7978e9c45a393942302acd1f1`
- Audit branch: `fix/gup-core-script-contracts-2026-10`
- Scope: deployment entrypoints, sourced copy helpers, installer entrypoint, and the Lua configuration graph they mutate.
- Status: baseline source inspection; remediation and executable validation are not yet complete.

## Atomized source baseline

GitHub blob SHA-1 values identify the exact source blobs inspected at the baseline revision.

| Atom | Path | Blob SHA |
|---|---|---|
| COPY-ENTRY | `copy.sh` | `a2d7486acdf410a906d08abeea71f0f4c18c2e58` |
| INSTALL-ENTRY | `install.sh` | `6814f738c960cc74a1acc50b0718799ddedec597` |
| UNINSTALL-ENTRY | `uninstall.sh` | `7692bd3893a954363cf0e62ed738597def783f7c` |
| COPY-MENU | `scripts/copy_menu.sh` | `e79dc79588f7609c010b01d15885cd773a80d39e` |
| COPY-BACKUP | `scripts/lib_backup.sh` | `800dcbba59c3c23a37a3c96cc2f304f19ba9c65d` |
| COPY-DETECT | `scripts/lib_detect.sh` | `f94e9b8fc386bd15b38ec6b5d6961af855124924` |
| COPY-PROMPTS | `scripts/lib_prompts.sh` | `81c4e04c6b00ab8ea0620d4d9abba6fdaa0b9844` |
| COPY-APPS | `scripts/lib_apps.sh` | `6a040843c0cfd361c6cd98df0c74651fadf5e871` |
| COPY-TRANSACTIONS | `scripts/lib_copy.sh` | `9a26d460b33fa8fcfe1ded1ef066edfc52a196c4` |
| COPY-RESOLUTION | `scripts/lib_resolution.sh` | `f1fa5d87ecea1e3e0cc0e528c56b84b8435c4484` |
| COPY-WAYBAR | `scripts/lib_waybar.sh` | `b501e37928f9debb547c687de593d6ebac40d6e5` |

## Confirmed contract defects

### C1 — Lua authority versus legacy Hyprland syntax

The active entrypoint `config/hypr/hyprland.lua` loads Lua modules, including `configs.Startup_Apps`, `configs.ENVariables`, and `configs.SystemSettings`. The corresponding authoritative files are `.lua`.

The copy helpers instead mutate:
- `config/hypr/configs/Startup_Apps.conf` in `scripts/lib_apps.sh` and `scripts/lib_detect.sh`;
- `config/hypr/configs/ENVariables.conf` and `SystemSettings.conf` in `scripts/lib_detect.sh`;
- `config/hypr/monitors.conf` in `scripts/lib_detect.sh`;
- `config/hypr/UserConfigs/01-UserDefaults.conf` in `scripts/lib_apps.sh`;
- legacy `.conf` startup/window/keybind overlays in `scripts/lib_copy.sh`.

These are not extension-only errors: the helpers write Hyprland directive syntax such as `exec-once = ...` and `env = ...` into paths that the Lua entrypoint does not load. A blind extension replacement would still produce invalid Lua. Remediation must preserve behavior in the Lua module graph.

### C2 — Prompt helper has undeclared runtime dependencies

`scripts/lib_prompts.sh` calls `print_color`, but the inspected entrypoint and sourced helper list do not define or source that function. It also expands color variables without defaults while `copy.sh` enables `set -u`. The prompt's keyboard-layout path edits a `.conf` file and writes non-Lua syntax to it.

### C3 — Copy dependency is not preflighted

`copy.sh` invokes `xdg-user-dirs-update` after creating the log. The command is not checked before invocation and is not declared by the copy entrypoint as a dependency. Under `set -Eeuo pipefail`, the pipeline aborts the run, but the resulting error does not explain the missing package or whether it is actually required; later code already has a fallback for the Pictures directory.

### C4 — Dry-run is not a graph contract

`install.sh --dry-run` checks a fixed list of module files and shell syntax, but does not validate all actual source edges, all helper dependencies, or runtime configuration paths. The copy orchestration unit similarly checks helper presence and syntax but not that mutations target loaded Lua modules.

### C5 — Runtime capability preservation is not established by syntax tests

The copy path has transactional and source-immutability tests, but those do not prove that hardware detection, keyboard selection, editor selection, optional startup applications, and NixOS-specific startup changes reach the modules loaded by `hyprland.lua`.

## GUP remediation and validation sequence

1. **Atomize:** keep each entrypoint/helper/configuration integration edge as a separately reviewable change.
2. **Hash:** record baseline and post-change blob hashes; preserve the baseline revision for superset comparison.
3. **Superset:** map each affected pre-existing behavior to its new Lua implementation; no feature is removed merely to make tests pass.
4. **Gate:** add executable tests for helper sourcing, unbound-variable behavior, Lua target existence/syntax, and capability reachability.
5. **Validate:** run shell syntax, ShellCheck on the declared core-script set, Golden Units, installer dry-run, and relevant runtime contracts. Do not run O.M.A.-2 while O.M.A.-1 is failing.
6. **Evidence:** attach test output and source hashes to the remediation PR; only claim gates that actually ran.

## Explicit non-claims

This baseline inspection did not execute ShellCheck or the repository test suite against a checked-out worktree. No claim is made that all shell diagnostics or all core-script defects have been enumerated. The findings above are source-grounded defects already visible before that executable pass.

## Remediation checkpoint — current branch head

- Validated source revision: 195e67c80f4da6a30d6297841cff36447b0cb6ec (the subsequent commit changes only this audit document).
- Golden Unit Protocol: PASS on the validated source revision.
- GUP Core Shell Contracts: PASS on the validated source revision. The gate ran bash -n across the core shell set, ShellCheck at warning severity, and the complete Golden Unit suite.
- O.M.A.-1 and O.M.A.-2 were not run by these CI jobs. The previously recorded runtime O.M.A.-1 failures remain unresolved on the host; O.M.A.-2 remains prohibited until O.M.A.-1 is green.
- PR remains draft because the configuration superset issue below is not yet resolved.

### Post-change source blob hashes

These Git blob SHA-1 values identify the source blobs in the current branch state; the listed source blobs are unchanged from the validated source revision.

| Atom | Path | Baseline blob | Current blob |
|---|---|---|---|
| BOOTSTRAP-ENTRY | Distro-Hyprland.sh | dcbaad8c9eb636af6ef9031b2a0f7973297ec077 | abdf3bc6c5a2d3345769c133b78053d15c1840e4 |
| INSTALL-ENTRY | install.sh | 6814f738c960cc74a1acc50b0718799ddedec597 | 3f2dcae6cdce2d4ae263a21ef43911963266b996 |
| UNINSTALL-ENTRY | uninstall.sh | 7692bd3893a954363cf0e62ed738597def783f7c | 4e1d324a3983408753a1864abdb15499829596ba |
| COPY-ENTRY | copy.sh | a2d7486acdf410a906d08abeea71f0f4c18c2e58 | 6e977157bb854c612450da475c0d4eb3c1f0f1b1 |
| COPY-BACKUP | scripts/lib_backup.sh | 800dcbba59c3c23a37a3c96cc2f304f19ba9c65d | 163100caf2ab3d7cec331083321759f08903d45a |
| COPY-DETECT | scripts/lib_detect.sh | f94e9b8fc386bd15b38ec6b5d6961af855124924 | 7b786dbb0b22aba444a21324293315c2cfcfab31 |
| COPY-PROMPTS | scripts/lib_prompts.sh | 81c4e04c6b00ab8ea0620d4d9abba6fdaa0b9844 | 0a7a6af42795e5d243837d8b796a8f97d1019d54 |
| COPY-APPS | scripts/lib_apps.sh | 6a040843c0cfd361c6cd98df0c74651fadf5e871 | 9ce9b9597d56c3d60b4fbdf5117ba64646190a26 |
| COPY-RESTORE | scripts/lib_copy.sh | 9a26d460b33fa8fcfe1ded1ef066edfc52a196c4 | 92f25f634e3e25658389c30de939671079127e99 |
| COPY-RESOLUTION | scripts/lib_resolution.sh | f1fa5d87ecea1e3e0cc0e528c56b84b8435c4484 | 8dce2c0d546eea142111cbc666ab310b2663cdb7 |
| COPY-WAYBAR | scripts/lib_waybar.sh | b501e37928f9debb547c687de593d6ebac40d6e5 | f5addf166dfe0a3f9b7efc60ae91ae11757ab520 |
| LUA-MUTATIONS | scripts/lib_lua_config.sh | absent | 8d43fd56406d58ca6e1134adfbf6f95204e39d00 |
| NVIDIA-INSTALLER | install-scripts/nvidia.sh | 931bce5c5061f61f6c024c462d427fbea7020c45 | f5adb773ee5678f4d85b9f36bdb58fe85c21c496 |
| CORE-SHELL-GATE | .github/workflows/core-shell-contracts.yml | absent | 138dd13538afa6ecd77ba2d7fcc8deeafe0a4dd1 |
| CORE-CONTRACT-UNIT | tests/unit/test-core-script-contracts.sh | absent | d9d8569a5684500c4660c91059eb1f577d2fde17 |
| LEGACY-ARCHIVE-UNIT | tests/unit/test-legacy-userconfig-archive.sh | absent | f86ef0225a060760e96f0374db13a1ee76efb6cc |

### Additional defects found and changes made

- The installer dry-run previously omitted several core helper files and did not syntax-check every top-level installer module. It now checks the full top-level module set and all core helper modules.
- Backup names used second-level timestamps and mv could collide with an existing backup path. Backup naming now includes nanoseconds and uses no-clobber moves with a postcondition check.
- The NVIDIA installer previously truncated a fixed state manifest and reused deterministic backup filenames on every run. State and backup directories are now scoped to a per-run identifier; tracked temporary files are cleaned on exit; strict mode exposes pipeline failures.
- Bootstrap/copy cleanup traps now exit on signals and propagate staging/partial-clone cleanup failures.
- Keyboard/editor/hardware/VM/NixOS adjustments now target the loaded Lua modules and use shared atomic mutation helpers.
- Legacy .conf user files are no longer copied into active Lua UserConfigs. They are preserved under UserConfigs/legacy-conf-backup/, with an explicit warning that they are inactive.

### Remaining blocker: legacy configuration superset

The archive behavior prevents silent loss and active-path contamination, but it does not translate old startup commands, environment settings, keybinds, monitor declarations, or window rules into their Lua equivalents. That means the old configuration's behavior is not yet a proven superset of the new deployment.

There is also a legacy compose_overlay_from_backup function in scripts/lib_resolution.sh that parses old .conf syntax and is not called by copy.sh; its current unit tests exercise the helper in isolation, not the deployment path. It must either be replaced by a Lua-aware migration path with end-to-end tests or explicitly retired together with a documented capability decision. The PR is intentionally draft until this is resolved.

### Validation boundary

The green CI gates establish syntax, ShellCheck warning cleanliness for the declared core script set, and the current Golden Unit suite. They do not prove that every optional system-mutating installer module works on real hardware. NVIDIA and other privileged installers remain static/unit-contract validated only; no privileged mutation was run in CI.

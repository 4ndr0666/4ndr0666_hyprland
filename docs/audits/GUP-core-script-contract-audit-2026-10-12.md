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

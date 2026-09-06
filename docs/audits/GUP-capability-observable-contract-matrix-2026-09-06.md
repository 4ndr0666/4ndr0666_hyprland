# GUP Capability-to-Observable Contract Matrix

**Date:** 2026-09-06  
**Baseline:** `9d6eb70a35d835395546556f134f0faaf528fdd6`  
**Golden Unit suite:** 43 registered units

## Purpose

This matrix converts the capability inventory into externally observable contracts. It is the working semantic/architectural gate artifact for Golden Unit Protocol v5.

> A material capability is adequately protected only when its authoritative implementation, integration edge, externally observable result, and regression invariant are all identifiable.

A Golden Unit that proves only file presence or syntax is **structural**, not behavioral.

## Contract matrix

| ID | Capability / contract | Authority | Integration edge | External observable | Existing Golden Unit | Coverage | Candidate gap |
|---|---|---|---|---|---|---|---|
| C01 | Pinned bootstrap resolves the reviewed repository revision | `Distro-Hyprland.sh`, `release.ref` | bootstrap → revision → installer | installation starts from declared lineage | `test-bootstrap.sh`, `test-release-ref-consistency.sh` | Strong structural/lineage | Verify immutable resolution end-to-end |
| C02 | Bootstrap documentation and executable entrypoint agree | `docs/BOOTSTRAP.md`, bootstrap entrypoint | documented command → executable path | documented installation path exists | `test-bootstrap-docs.sh`, `test-installer-entrypoint.sh` | Structural | None identified |
| C03 | Unsupported/failed installer states fail closed | installer core | detection/provisioning → failure boundary | nonzero failure rather than partial success | `test-installer-fail-closed.sh`, `test-package-boundary.sh` | Strong | None identified |
| C04 | Package provisioning remains atomic | `install-scripts/core/packages.sh` | installer → package backend | no partial authoritative manifest state | `test-package-manifest-atomicity.sh`, `test-pacman-sync-invariant.sh` | Strong | None identified |
| C05 | Systemd state reconciliation is explicit | `install-scripts/core/systemd.sh` | installer → systemd | enabled/disabled/absent state is deterministic | `test-systemd.sh` | Strong | None identified |
| C06 | Filesystem provisioning reconciles destination state | `install-scripts/core/files.sh` | installer → destination | expected file/symlink state exists | `test-files.sh` | Strong structural | Runtime consumer validation may be needed |
| C07 | Dotfile deployment is transactional | `copy.sh`, `scripts/lib_copy.sh` | copy orchestrator → transaction | failed deployment leaves recoverable prior state | `test-dotfiles.sh`, `test-dotfile-backup-atomicity.sh`, `test-copy-transaction-runtime.sh` | Strong | None identified |
| C08 | Repository source remains immutable during customization | copy resolution/customization boundary | repository source → temporary representation → destination | source tree remains authoritative | `test-copy-source-immutability.sh` | Strong | None identified |
| C09 | Copy operation is independent of caller CWD | `copy.sh` | arbitrary cwd → repository-root resolution | identical deployment semantics | `test-copy-cwd-portability.sh` | Explicit | None identified |
| C10 | Destructive copy patterns are prohibited | copy/install boundary | deployment implementation | no unsafe destructive primitive bypasses transaction | `test-dotfile-destructive-patterns.sh` | Strong | None identified |
| C11 | Configuration-only repositories remain valid | repository/copy boundary | repository → configuration-only deployment | no dependency on unrelated assets | `test-config-only-dot-repository.sh` | Explicit | None identified |
| C12 | Remote executable dependencies are pinned/controlled | CI/bootstrap/install boundaries | remote source → execution | mutable remote execution cannot enter trusted path | `test-remote-exec-invariant.sh`, `test-github-actions-pinned.sh` | Strong | None identified |
| C13 | Legacy installer authorities remain retired | installer architecture | old entrypoints → retirement boundary | obsolete path cannot become authoritative | `test-legacy-installer-removal.sh`, `test-no-legacy-install-package.sh` | Explicit | None identified |
| C14 | Self-update authority remains retired | update boundary | repository → runtime update | deployment cannot silently self-update | `test-self-update-boundary.sh` | Explicit | None identified |
| C15 | SDDM changes have rollback semantics | SDDM installer path | install → SDDM mutation → rollback | failed operation restores prior state | `test-sddm-rollback.sh` | Strong | None identified |
| C16 | Copy orchestration follows declared phase ordering | `copy.sh`, `scripts/lib_copy.sh` | orchestrator → phases | phases execute deterministically | `test-copy-orchestration-boundary.sh`, `test-copy-phase1-atomicity.sh` | Strong | None identified |
| C17 | Waybar configuration remains connected to canonical paths | Waybar integration | deployment → Waybar | Waybar resolves intended scripts/configuration | `test-waybar-script-config-boundary.sh` | Strong boundary | Runtime launch not exercised |
| C18 | Waybar backup symlinks restore from directory context | `scripts/lib_copy.sh` | backup → restore | relative symlink resolves correctly | `test-waybar-symlink-restoration.sh` | Explicit | None identified |
| C19 | Rofi search remains connected to authoritative implementation | Rofi search integration | keybind → `RofiSearch.sh` → Rofi | search invocation reaches configured implementation | `test-rofi-search-config-boundary.sh` | Boundary | Broader Rofi behaviors unproven |
| C20 | Wallpaper effects remain connected | `WallpaperEffects.sh` | keybind → effect helper → process | effect invocation reaches intended process | `test-wallpaper-effect-config-boundary.sh` | Boundary | Lifecycle semantics partial |
| C21 | Compositor shell installers remain connected | compositor installer helpers | installer → compositor shell | expected compositor component provisioned | `test-compositor-shell-installers.sh` | Boundary | Runtime behavior partial |
| C22 | Wallust → Waybar pipeline remains coherent | Wallust/Waybar canonical path | wallpaper → Wallust → generated Waybar state | palette/theme reaches Waybar | `test-waybar-wallust-pipeline.sh`, `test-waybar-wallust-orchestration.sh` | Strong | None identified |
| C23 | Game mode remains connected to Wallust/theme orchestration | game mode integration | game mode → theme/palette path | expected theme transition | `test-gamemode-wallust-boundary.sh` | Boundary | Runtime observation limited |
| C24 | Quickshell overview has one authoritative implementation | `config/quickshell/overview` | keybind → overview module | requested overview resolves canonically | `test-quickshell-overview-boundary.sh`, `test-quickshell-overview-single-source.sh` | Strong | None identified |
| C25 | AGS remains retired as competing authority | architecture retirement boundary | legacy AGS → no active integration | no AGS authority remains | `test-ags-retirement-boundary.sh` | Explicit | None identified |
| C26 | Runtime helper orchestration has declared boundaries | `config/hypr/scripts/` | Hyprland → helper → external process | correct failure/success propagation | `test-runtime-orchestration-boundaries.sh` | Broad boundary | Individual lifecycle contracts need decomposition |
| C27 | Current repository tree contains expected component set | repository tree | source tree → deployment inventory | supported components are present | `test-current-tree-integrity.sh` | Structural | Does not prove runtime reachability |
| C28 | Runtime paths contain no stale machine-local references | runtime configuration | deployed config → executable path | runtime path is portable | `test-runtime-path-integrity.sh` | Explicit | None identified |
| C29 | Weather module returns deterministic configured fallback | `Weather.sh` | Waybar → weather → geolocation/API → JSON | valid fallback or deterministic error | `test-weather-fallback-boundary.sh` | Strong | None identified |
| C30 | Keybind definitions resolve to intended live implementations | `config/hypr/configs/Keybinds.lua` | Hyprland config → script/command | user keypress reaches intended capability | current keybind/tree/runtime units | Partial | **High-value candidate** |
| C31 | Keybind parser/visualization reflects authoritative definitions | `KeyBinds.sh`, `keybinds_parser.py`, Quickshell service | config → parser → UI | displayed keybinds match live definitions | runtime/tree coverage | Partial | **High-value candidate** |
| C32 | Rofi launcher/window switcher remains operational | Rofi + keybinds | keybind → Rofi | launcher/window selection works | search boundary only | Partial | **Candidate** |
| C33 | Notification stack remains operational | SwayNC configuration | session → notification daemon → UI | notifications render through intended stack | tree/runtime coverage | Weak | **Candidate** |
| C34 | Terminal selection remains coherent | `user_defaults.term`, terminal paths | keybind → selected terminal | configured terminal opens | tree/config coverage | Weak | **Candidate** |
| C35 | Monitor profile selection reaches deployed Hyprland | `Monitor_Profiles/` | deployment → profile selection → Hyprland | selected topology applies | tree/config coverage | Weak | **Candidate** |
| C36 | User configuration overrides remain connected | `UserConfigs/`, `UserScripts/` | copy → user config → sourced runtime | override changes effective behavior | structural coverage | Weak | **Candidate** |
| C37 | Cava visualization has correct process lifecycle | `WaybarCava.sh`, Cava config | Waybar → helper → Cava | visualization starts/stops without stale state | runtime boundary coverage | Partial | **Candidate** |
| C38 | Portal lifecycle converges on intended session state | `PortalHyprland.sh` | session → portal process | required portal state is established | runtime boundary coverage | Partial | **Candidate** |
| C39 | Overview toggle reaches canonical Quickshell implementation | `OverviewToggle.sh` | keybind → toggle helper → Quickshell | overview changes state | overview boundary + runtime boundary | Partial | **Candidate** |
| C40 | Autodispatch selects intended process/session state | `Tak0-Autodispatch.sh` | process inspection → dispatch | correct target receives dispatch | runtime boundary coverage | Partial | **Candidate** |
| C41 | Wallpaper effects converge without stale process state | `WallpaperEffects.sh` | wallpaper/event → signal/process | intended effect state established | effect boundary | Partial | **Candidate** |
| C42 | Keyboard-layout switcher changes intended layout and respects ignores | `KeyboardLayout.sh` | input/device → selection | active layout changes only for eligible devices | predicate coverage | Partial | **Candidate** |
| C43 | Initialization helper launches correct available component | `4ndr0init.sh` | startup → candidate discovery → launch | intended component becomes active | helper/runtime coverage | Partial | **Candidate** |
| C44 | Uninstall reverses authoritative installed state | `uninstall.sh` | installed tree → removal/reversion | supported artifacts removed without authoritative orphans | current-tree/install coverage | Weak | **High-value candidate** |
| C45 | Deployment preserves externally meaningful capability set | copy/update architecture | baseline capability set → deployment transaction | no supported capability silently disappears | copy transaction + current-tree units | Architectural | **High-value architectural invariant** |
| C46 | Documentation describes currently authoritative paths | README/docs | documentation → actual entrypoints/components | documented path leads to supported behavior | bootstrap/docs units | Structural | **Candidate** |

## Priority

### Strongly protected

C01–C18, C22, C24–C29 are substantially protected by existing Golden Units.

### Boundary/structural but incomplete

C19–C21, C23, C26–C28 and C30–C43 have meaningful evidence but do not uniformly prove the complete external observable.

### Highest-value candidates

1. **C30 — keybind reachability**
2. **C31 — keybind representation consistency**
3. **C37 — Cava lifecycle**
4. **C38 — portal lifecycle**
5. **C44 — uninstall symmetry**
6. **C45 — capability-preserving deployment**

C32–C36 and C39–C43 are secondary candidates and should become new Golden Units only when repository inspection demonstrates a material invariant not already transitively protected.

## Architectural invariant: capability-preserving deployment

C45 is not a file-count test. The desired property is:

```text
Supported capabilities at baseline
        ⊆
Supported capabilities after deployment/update
```

subject to intentional retirement decisions already recorded by GUP.

The invariant must account for authoritative implementation, integration edge, required runtime/configuration artifacts, intentional retirement boundaries, deployment transaction boundaries, and user-visible capability.

## D6 / EAFP constraint

Existing bounded `|| true` and stderr suppression must not be removed solely because they match a static pattern. Each occurrence must be classified as optional cleanup/probing or authoritative failure. Authoritative failures remain loud; non-authoritative cleanup may normalize expected absence.

## Next gate

Validate C30–C45 against actual integration edges. Only material, currently unprotected contracts should become new Golden Units or architectural remediations.

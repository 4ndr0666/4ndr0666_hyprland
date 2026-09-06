# GUP Capability-to-Observable Coverage Baseline

**Date:** 2026-09-06  
**Repository:** `4ndr0666/4ndr0666_hyprland`  
**Audit stage:** Golden Unit Protocol v5 — semantic / architectural gate preparation  
**Current main:** `9d6eb70a35d835395546556f134f0faaf528fdd6`  
**Golden Units registered:** 43

## Purpose

This document records the externally meaningful capability inventory established during the GUP audit. It is the historical baseline for the next phase: construction of the capability-to-observable contract matrix.

The objective is not to maximize Golden Unit count. The objective is to establish whether every material capability has an authoritative implementation, a real integration path, an externally meaningful observable contract, and an existing Golden Unit that protects the relevant invariant.

## Assessment model

For each capability, evaluate:

1. **Authoritative implementation** — exactly one source of truth.
2. **Integration path** — an actual caller/deployment/runtime path connects the implementation to its consumers.
3. **Observable contract** — behavior that an external user, system component, or deployment transaction can actually observe.
4. **Golden Unit** — an existing test that protects the invariant rather than merely the implementation's presence.
5. **Superset status** — no omission, weakening, or orphaning relative to the supported capability set of the preceding stable revision.

The architectural chain is:

```text
repository component
        ↓
authoritative implementation
        ↓
integration edge
        ↓
external observable
        ↓
Golden Unit invariant
```

A missing final edge is a candidate GUP gap. A component merely existing in the repository is not sufficient evidence of behavioral coverage.

## Capability inventory

| Capability | Authoritative implementation | Integration path | Existing GUP coverage | Assessment |
|---|---|---|---|---|
| Bootstrap / pinned installation | `Distro-Hyprland.sh`, `docs/BOOTSTRAP.md`, `release.ref` | pinned bootstrap → revision verification → installer | bootstrap/current-tree units | Covered; release-lineage invariant deserves explicit verification |
| Host/distro detection | installer core detection helpers | bootstrap → distro-specific provisioning | installer/distro boundary units | Covered |
| Package provisioning | `install-scripts/core/packages.sh` | installer → package backend → component installers | package/install units | Covered |
| Systemd provisioning | `install-scripts/core/systemd.sh` | installer → unit state inspection/write/enable path | systemd units | Covered |
| Filesystem/component provisioning | `install-scripts/core/files.sh` | installer → component destination/state reconciliation | file-state units | Covered |
| Main configuration deployment | `copy.sh`, `scripts/lib_copy.sh` | copy orchestrator → resolution → transactional copy/restore | copy phase/transaction/atomicity units | Strongly covered |
| Backup / restore | `scripts/lib_backup.sh`, copy transaction path | pre-copy backup → deployment → restoration on failure | backup/copy transaction units | Strongly covered |
| Caller-CWD independence | `copy.sh` path normalization | arbitrary invocation directory → repository-root resolution → helpers | cwd regression unit | Explicitly covered |
| Repository immutability during customization | copy resolution/customization boundary | repository source → temporary/runtime representation → destination | repository-source preservation unit | Explicitly covered |
| Installed-version/state detection | copy/install state helpers | current state → reconciliation decision | copy/runtime units | Covered; initial-state optionality remains an invariant |
| Hyprland Lua configuration | `config/hypr/` Lua tree | deployment → `~/.config/hypr` → Hyprland | current-tree/config integrity units | Structural coverage; runtime semantic coverage weaker |
| Keybinds / startup configuration | `config/hypr/configs/` | Hyprland config → runtime keybind/startup behavior | keybind/current-tree units | Partially covered |
| Monitor profiles / user variables | `Monitor_Profiles/`, `UserConfigs/` | deployed config → user/runtime selection | tree/config units | Mostly structural |
| Runtime workspace utilities | `config/hypr/scripts/` | keybind/startup → helper scripts → Hyprland IPC/processes | selected runtime units | Mixed coverage |
| Wallpaper selection/orchestration | canonical wallpaper/Wallust path | `SUPER+W` → wallpaper selection → Wallust → dependent templates | Wallust/orchestration units | Strongly covered |
| Dynamic palette generation | Wallust integration | wallpaper → Wallust → generated palette/templates | Wallust pipeline units | Strongly covered |
| Waybar theming | canonical Waybar Wallust integration | Wallust → Waybar template/config → reload | Wallust/Waybar units | Covered; symlink edge explicitly covered |
| Waybar backup symlink restoration | `scripts/lib_copy.sh` / restoration logic | backup directory → relative symlink resolution → restore | Waybar symlink regression unit | Explicitly covered after PR #62 |
| Dark/light mode | `DarkLight.sh` | user/runtime invocation → theme mutation/reload | DarkLight boundary unit | Covered at boundary; external compositor behavior less direct |
| Global refresh/reload | `Refresh.sh` | reload trigger → Waybar/compositor/menu refresh | Refresh/runtime unit | Covered |
| Quickshell overview | `config/quickshell/overview` | keybind → active shell → local module graph | single-source/current-tree unit | Strong structural coverage |
| Rofi/application launcher | `config/rofi/` | Hyprland keybind → Rofi | configuration/current-tree coverage | Under-tested semantically |
| SwayNC notifications | `config/swaync/` | runtime session → notification daemon | tree/config coverage | Under-tested semantically |
| Kitty terminal | `config/kitty/` | terminal keybind → Kitty | tree/config coverage | Under-tested semantically |
| Ghostty terminal | `config/ghostty/` | terminal configuration deployment → Ghostty | tree/config coverage | Under-tested semantically |
| Cava audio visualization | `config/cava/`, `WaybarCava.sh` | Waybar/runtime invocation → Cava/process lifecycle | Cava/runtime units | Partially covered; lifecycle invariants deserve attention |
| Weather Waybar module | `config/hypr/UserScripts/Weather.sh` | Waybar → weather script → geolocation/API → deterministic JSON | weather fallback boundary unit | Explicitly covered after PR #63 |
| Weather fallback contract | `Weather.sh` | failed automatic location → explicit `WEATHER_CITY` → error or valid result | `test-weather-fallback-boundary.sh` | Strongly covered |
| Portal lifecycle | `PortalHyprland.sh` | session/runtime → portal process lifecycle | runtime coverage | Partial |
| Overview toggle | `OverviewToggle.sh` | keybind → Quickshell overview | runtime coverage | Partial |
| Autodispatch | `Tak0-Autodispatch.sh` | process/session state → dispatch logic | runtime coverage | Partial |
| Wallpaper effects | `WallpaperEffects.sh` | wallpaper/event → process signal | runtime coverage | Partial |
| Keyboard layout handling | `KeyboardLayout.sh` | input/device state → layout selection/filtering | predicate/runtime coverage | Partial |
| Initialization helpers | `4ndr0init.sh` | runtime component → candidate discovery → launch | helper/runtime units | Partial |
| Uninstallation | `uninstall.sh` | installed tree → removal | current-tree/install coverage | Weak semantic coverage |
| Update/synchronization | current deployment/update harnesses | repository → installed configuration reconciliation | copy/update units | Strong transaction semantics; weaker complete capability preservation |
| Assets/wallpapers | `assets/`, `wallpapers/` | deployment → runtime consumers | current-tree integrity | Structural |
| Documentation/bootstrap contract | `README.md`, `docs/` | documented entrypoint → actual implementation | documentation/tree checks | Structural, not behaviorally enforced |

## Strongly protected invariants

The current GUP suite has strong coverage around:

- transactional copy semantics;
- atomicity and cleanup;
- repository-source preservation;
- caller-CWD independence;
- backup/restore;
- Wallust orchestration;
- canonical Waybar paths;
- Waybar symlink restoration;
- Quickshell single-source ownership;
- weather fallback behavior;
- removal of obsolete AGS/self-update authorities.

These are the areas where prior GUP remediation materially converted concrete defects into enforced invariants.

## Structurally protected, semantically weaker capabilities

The following components are present and integrated at a structural level, but the current suite does not yet appear to prove their full externally observable behavior:

- Rofi;
- SwayNC;
- Kitty/Ghostty;
- monitor profiles;
- user configuration;
- portions of the Hyprland keybind/startup graph;
- uninstall behavior;
- asset deployment.

The principal risk is that a component can remain present while its invocation or deployment edge silently disappears.

## Distributed runtime contracts

The following helpers cross process, filesystem, or desktop-session boundaries and therefore require particular D6/D9 scrutiny:

- `WaybarCava.sh`;
- `PortalHyprland.sh`;
- `OverviewToggle.sh`;
- `Tak0-Autodispatch.sh`;
- `WallpaperEffects.sh`;
- `KeyboardLayout.sh`;
- `4ndr0init.sh`.

For these, tolerated cleanup/probe failures are not themselves defects. The invariant to establish is that the correct state transition occurs and that authoritative failures propagate loudly.

## Highest-value candidate invariants

The following candidates should drive construction of the capability-to-observable contract matrix:

1. **Keybind reachability** — every externally documented keybind resolves to exactly one live implementation.
2. **Runtime process lifecycle** — Cava, portal, overview, wallpaper-effect, and initialization helpers prove the intended process transition rather than merely tolerating process-control failures.
3. **Configuration-to-runtime connectivity** — Rofi, SwayNC, Kitty/Ghostty, monitor profiles, and user configuration prove that deployed configuration remains connected to its runtime consumer.
4. **Uninstall symmetry** — installation creates a defined state and uninstall removes or reverts that state without leaving authoritative artifacts behind.
5. **Bootstrap lineage** — the documented pinned bootstrap path and `release.ref` prove that bootstrap cannot silently resolve to an unreviewed mutable revision.
6. **Capability-preserving deployment** — the copy transaction preserves the externally meaningful capability set of the supported baseline; this is an architectural invariant rather than merely another shell test.

## GUP decision rule

Do **not** add Golden Units merely to increase the suite count.

A new unit is warranted when a material externally observable invariant is currently unprotected. A component's presence, a duplicated implementation detail, or a superficial string check is not sufficient justification.

The next audit phase is therefore to construct the full capability-to-observable contract matrix and determine, for each candidate invariant:

- whether an existing Golden Unit already protects it;
- whether the current unit protects the actual observable contract or only structure;
- whether the invariant is part of the historical superset requirement;
- whether a new Golden Unit is required;
- or whether the correct remediation is architectural rather than test-only.

## Historical significance

This file is intentionally retained as an audit artifact. It records the state of reasoning at the semantic/architectural gate boundary before the next GUP pass, so subsequent changes can be evaluated against this capability inventory rather than against a moving or reconstructed understanding of the repository.

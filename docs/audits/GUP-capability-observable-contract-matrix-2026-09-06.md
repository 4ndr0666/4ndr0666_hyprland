# GUP Capability-to-Observable Contract Matrix

**Date:** 2026-09-06  
**Baseline:** `09077d0eb9fd1eb3be1ebd0b1202f634b3b3c1b1`  
**Golden Unit suite:** 49 registered units after semantic-boundary expansion

## Purpose

This matrix converts the capability inventory into externally observable contracts and is the working semantic/architectural gate artifact for Golden Unit Protocol v5.

> A material capability is adequately protected only when its authoritative implementation, integration edge, externally observable result, and regression invariant are all identifiable.

A Golden Unit that proves only file presence or syntax is **structural**, not behavioral.

## Highest-priority contracts

C30 — keybind reachability; C31 — keybind representation consistency; C37 — Cava lifecycle; C38 — portal lifecycle; C44 — uninstall symmetry; C45 — capability-preserving deployment.

## Established semantic Golden Units

The current branch has established and registered focused semantic units for:

- **C30 — keybind reachability:** repository-backed `scriptsDir` and `UserScripts` targets referenced by authoritative Lua bindings must resolve to files.
- **C31 — keybind representation consistency:** the keybind presentation parser must consume the authoritative Lua `hl.bind(...)` representation and expose representative user-visible bindings.
- **C37 — Cava lifecycle:** the Cava helper must create its runtime configuration, stream translated output, and clean its pidfile and temporary configuration on exit.
- **C38 — portal lifecycle:** the portal helper must clear conflicting portal processes, resolve both Hyprland-specific and generic portal candidates, and fail loudly when startup candidates are unavailable.
- **C46 — documentation authority:** README deployment documentation must name only live repository entrypoints.

The resulting registered suite is **49 units**. The GUP workflow has passed the expanded suite through the C37/C38/C46 additions.

## Confirmed gap remediation

The semantic keybind pass exposed a real authority mismatch: `KeyBinds.sh` delegated to a parser that understood legacy `bind = ...` syntax while the authoritative configuration uses Lua `hl.bind(...)` declarations. The parser was aligned to the Lua authority, and a missing Alacritty keybind target was restored with executable mode preserved.

The documentation pass also confirmed that `release.sh`, `upgrade.sh`, and `update-dots.sh` are not live root entrypoints. README claims for the removed `release.sh` and `upgrade.sh` paths were removed and the live `copy.sh`/`uninstall.sh` authorities were documented instead.

## Architectural invariant: capability-preserving deployment

C45 is not reduced to a file-count test. The desired property is:

```text
Supported capabilities at baseline
        ⊆
Supported capabilities after deployment/update
```

subject to intentional retirement decisions already recorded by GUP. The invariant accounts for authoritative implementation, integration edge, required runtime/configuration artifacts, retirement boundaries, transaction boundaries, and user-visible capability.

## Remaining architectural gate

**C44 — uninstall symmetry** remains only partially protected. The current uninstall authority operates on the installer-owned package manifest and deliberately retains ownership state when package removal fails. It does not constitute a complete reverse deployment of the configuration tree. This is an architectural boundary, not a reason to add a superficial `rm`-presence test.

**C45 — capability-preserving deployment** remains the final architectural gate. The existing Golden Units strongly protect transaction semantics and selected capability edges, but a complete automated proof of the baseline capability superset still requires the capability inventory and intentional-retirement model to be treated as authoritative semantic data rather than inferred from file counts.

## D6 / EAFP constraint

Existing bounded `|| true` and stderr suppression must not be removed solely because they match a static pattern. Each occurrence must be classified by whether it represents optional cleanup/probing or an authoritative failure. Authoritative failures remain loud; non-authoritative cleanup may normalize expected absence.

## Validation boundary

The C30–C45 set is the bounded semantic validation boundary. C30, C31, C37, and C38 are now materially protected by focused Golden Units. C44 and C45 remain the architectural decisions requiring judgment before the suite can be declared semantically complete.

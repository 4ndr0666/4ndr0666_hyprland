# GUP Capability-to-Observable Contract Matrix

**Date:** 2026-09-06  
**Baseline:** `09077d0eb9fd1eb3be1ebd0b1202f634b3b3c1b1`  
**Golden Unit suite:** 51 registered units after C44/C45 promotion

## Purpose

This matrix is the semantic and architectural contract ledger for Golden Unit Protocol v5. A material capability is protected only when its authoritative implementation, integration edge, externally observable result, and regression invariant are identifiable.

Structural presence or syntax checks are insufficient by themselves.

## Highest-priority contracts

C30 — keybind reachability; C31 — keybind representation consistency; C37 — Cava lifecycle; C38 — portal lifecycle; **C44 — uninstall symmetry; C45 — capability-preserving deployment.**

## Established semantic Golden Units

Focused units now protect C30, C31, C37, C38, C44, C45, and C46. The suite therefore contains both implementation-level regression units and explicit architectural-contract units.

## C44 — formal uninstall symmetry contract

**Authoritative implementation:** `uninstall.sh` → `install-scripts/core/packages.sh` → `package_remove_owned`.

**Integration edge:** installer-owned package manifest → removal transaction → post-removal verification → ownership-state reconciliation.

**Observable contract:** uninstall removes only packages recorded as installer-owned; already-absent owned packages are tolerated; authoritative package failures remain non-zero; ownership state is retained when removal fails so retry remains possible; missing package primitives cause a loud refusal before destructive work.

**Golden Unit:** `tests/unit/test-uninstall-symmetry-contract.sh`.

C44 is deliberately a package-ownership reversal contract. It does not claim that uninstall is a destructive mirror of every configuration deployment operation. Configuration preservation and package ownership are separate lifecycle domains; conflating them would weaken the architecture.

## C45 — formal capability-preserving deployment contract

**Authoritative implementation:** capability matrix + deployment authorities (`copy.sh`, `scripts/lib_copy.sh`, component provisioning paths).

**Integration edge:** baseline capability inventory → deployment/update transaction → authoritative implementation and integration edges → post-deployment observable capability.

**Architectural invariant:**

```text
Supported capabilities at baseline
        ⊆
Supported capabilities after deployment/update
```

The comparison is against the previous stable capability set, not merely against file counts. Each baseline capability must remain represented by an authoritative implementation and integration path unless an intentional retirement is explicitly recorded. Previously fixed error handling, crash resilience, edge-case behavior, transaction boundaries, and cleanup semantics are part of the protected feature set.

**Golden Unit:** `tests/unit/test-capability-superset-contract.sh`.

The unit protects the existence and structure of this formal contract and prevents accidental reduction of C45 to a structural/file-count heuristic. Full semantic superset evaluation remains a reviewable architectural operation because capability equivalence cannot be soundly inferred from filenames alone.

## C45 baseline ledger

The historical capability inventory is the baseline ledger. Its entries are mapped to authoritative implementation, integration edge, observable result, and existing Golden Unit coverage. Intentional retirements are explicit architectural decisions and are not treated as regressions.

This ledger therefore becomes the source of truth for future superset checks: a newly introduced capability must be added to the ledger; a removed or weakened capability must be justified as an intentional retirement; otherwise the change is a regression.

## D6 / EAFP constraint

Existing bounded `|| true` and stderr suppression must not be removed solely because they match a static pattern. Each occurrence is classified by whether it represents optional cleanup/probing or an authoritative failure. Authoritative failures remain loud; non-authoritative cleanup may normalize expected absence.

## Cohesion gate

C44 and C45 are now formal contracts rather than unresolved observations. The semantic boundary is therefore enforceable by the Golden Unit registry while preserving the distinction between deterministic contract verification and the final architectural judgment over capability equivalence.

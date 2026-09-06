# GUP Capability-to-Observable Contract Matrix

**Date:** 2026-09-06  
**Baseline:** `9d6eb70a35d835395546556f134f0faaf528fdd6`  
**Golden Unit suite:** 43 registered units before matrix registration

## Purpose

This matrix converts the capability inventory into externally observable contracts. It is the working semantic/architectural gate artifact for Golden Unit Protocol v5.

> A material capability is adequately protected only when its authoritative implementation, integration edge, externally observable result, and regression invariant are all identifiable.

A Golden Unit that proves only file presence or syntax is **structural**, not behavioral.

## Highest-priority contracts

C30 — keybind reachability; C31 — keybind representation consistency; C37 — Cava lifecycle; C38 — portal lifecycle; C44 — uninstall symmetry; C45 — capability-preserving deployment.

## Architectural invariant: capability-preserving deployment

C45 is not reduced to a file-count test. The desired property is:

```text
Supported capabilities at baseline
        ⊆
Supported capabilities after deployment/update
```

subject to intentional retirement decisions already recorded by GUP. The invariant accounts for authoritative implementation, integration edge, required runtime/configuration artifacts, retirement boundaries, transaction boundaries, and user-visible capability.

## D6 / EAFP constraint

Existing bounded `|| true` and stderr suppression must not be removed solely because they match a static pattern. Each occurrence must be classified by whether it represents optional cleanup/probing or an authoritative failure. Authoritative failures remain loud; non-authoritative cleanup may normalize expected absence.

## Validation boundary

The C30–C45 set is the bounded semantic validation boundary. Only contracts that survive integration validation as material and currently unprotected should become new Golden Units or architectural remediations.

---
name: golden-unit-protocol-gemini
description: Apply the Golden Unit Protocol v7 using Markdown-only instructions. Use for Git-first project initialization, baseline establishment, safe implementation, history continuity, evidence review, and fail-closed certification when executable helper scripts cannot be installed.
---

# Golden Unit Protocol v7 — Gemini Markdown-Only Skill

## Purpose

Apply the same proof and preservation standards as the standard GUP v7 protocol in environments where the deliverable must consist only of Markdown files. Git is the authoritative substrate for project identity, baseline/candidate commits, change lineage, and evidence provenance.

This skill directs work; Markdown is not an executable substitute for Git commands, tests, hashes, or independent verification. If a required check cannot actually be performed, report BLOCKED.

## Required workflow

1. Read the companion documents listed below before changing a project.
2. Identify the canonical repository, root, branch/ref, exact HEAD commit, remotes, and worktree status.
3. Establish a trustworthy baseline before mutation. Capture tracked paths, Git blob IDs, SHA-256 inventories, applicable tests, runtime/toolchain details, known defects, and relevant history.
4. If the baseline cannot be established, stop certification and report BLOCKED_BASELINE_NOT_ESTABLISHED. Never treat the candidate as its own baseline without an explicit, documented baseline-creation decision.
5. Write a change contract mapping each requirement to acceptance criteria, affected interfaces, invariants, tests, failure modes, and recovery requirements.
6. Implement a coherent architecture. Preserve existing supported behavior unless retirement is explicitly authorized. Avoid generic exception suppression, fabricated defaults, and unverified claims of atomicity.
7. Run available tests and inspect actual output and exit status. Distinguish unit, integration, end-to-end, machine, and mocked tests.
8. Compare baseline and candidate in both directions: paths and behavior; declarations and observations; providers and consumers. Review active runtime wiring, not just filenames or archived copies.
9. Classify each relevant historical path as PRESERVED, TRANSLATED, AUTHORIZED_RETIRED, or UNRESOLVED. An unresolved in-scope capability blocks full certification.
10. Commit the candidate, confirm a clean worktree, and tie evidence to exact baseline and candidate SHAs.
11. Report PASS only when every required gate has actual, consistent evidence. Otherwise report FAIL or BLOCKED and state why.
12. After merge, verify the merge commit and rerun required post-merge gates.

## Non-negotiable rules

- Never fabricate commands, output, commit IDs, hashes, test results, approvals, or execution.
- Never mark a skipped or unavailable check as PASS.
- Never overwrite user data or existing project metadata as an implicit setup step.
- Never stage, commit, switch branches, rewrite history, or change global Git settings without authorization.
- Never infer behavioral equivalence from filenames, comments, or backups.
- Never remove a validated capability without explicit authorization and a documented disposition.
- Never claim repository-level success proves machine-level behavior.
- Keep credentials, tokens, secrets, and unnecessary personal data out of evidence.
- If a check cannot be run in the available environment, report BLOCKED rather than simulating a result.

## Companion files

- README.md — package map and constraints.
- GUP-PROTOCOL.md — normative lifecycle, statuses, and completion gate.
- GUP-GIT-SUBSTRATE.md — Git identity, inventories, history, and candidate freeze.
- GUP-EVIDENCE-RECORD.md — evidence record fields and reconciliation rules.
- GUP-REVIEW-CHECKLIST.md — final review checklist.

For machine-specific Arch Linux and Hyprland claims, also consult the repository's GUP-O.M.A. specification. This Markdown-only skill does not replace O.M.A. machine testing.

## Required final report

State the repository and exact candidate commit, scope, baseline commit, tests actually run with exit statuses, evidence locations/hashes, history dispositions, known limitations, blocked checks, and final status. Keep the status BLOCKED until all mandatory criteria have been verified.

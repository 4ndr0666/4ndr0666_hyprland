# Golden Unit Protocol (GUP) v7.0.0

## Status and scope

This document defines the normative project-start and change-certification protocol. Git is the source-of-truth substrate for project identity, baseline, candidate state, history, and evidence. A passing test suite alone is not certification.

GUP-O.M.A. remains a separate machine-assurance layer. GUP v7 establishes the project-level foundation on which O.M.A. depends.

## Non-negotiable invariants

1. **One authoritative Git history.** Every certified state is tied to an exact commit SHA and repository identity. Never certify an uncommitted or ambiguously identified tree.
2. **Baseline before mutation.** Record the pre-change commit, tracked-file inventory, worktree state, applicable tests, supported behavior, and known defects before implementation.
3. **Behavioral superset by default.** Preserve existing supported behavior while adding or correcting behavior. Any unapproved validated capability loss is a release blocker. A removal requires explicit authorization and an evidence-backed disposition.
4. **Evidence over assertion.** Claims must be reproducible from captured commands, exit codes, exact commit IDs, hashes, test output, and reviewed semantic comparisons.
5. **Fail closed.** Missing evidence, contradictory state, tool errors, incomplete rollback, dirty candidate state, or an unresolved high-impact discrepancy means BLOCKED or FAIL, never PASS.
6. **Idempotency.** Repeating a supported operation from the same valid state must converge to the same valid state without duplicate artifacts or cumulative damage.
7. **Atomicity or recoverability.** Persistent mutations must be atomic or have a documented, tested recovery transaction. Cleanup must be guaranteed across success and failure paths; cleanup failure is itself visible.
8. **No synthetic success.** Do not swallow nonrecoverable errors, substitute empty/default evidence, ignore nonzero statuses, or report mocked checks as real execution.
9. **Correct tool for the domain.** Select a coherent architecture and appropriate language/runtime. Avoid architectural hybrids, fragile check-then-act logic where direct execution with explicit error handling is safer, and micro-fixes that preserve a broken monolith.
10. **No placeholders in release artifacts.** Final runnable instructions, scripts, manifests, and evidence must not contain unresolved TODOs, guessed hashes, invented results, or commands with missing critical arguments.

## Lifecycle

### Phase 0 — Identify the project

- Identify the canonical repository URL and owner.
- Verify Git is available; inspect repository root, branch/ref, remotes, and worktree state.
- For a new project, initialize Git only in the intended root. Refuse accidental nested repositories unless nesting is an explicit architecture decision.
- Create a project manifest starting in BLOCKED_BASELINE_NOT_ESTABLISHED. Initialization must be idempotent and must not overwrite user data, stage files, create commits, or mutate global Git configuration without explicit authorization.

### Phase 1 — Establish the baseline

- Record exact baseline commit SHA and symbolic ref where available.
- Record git status --porcelain=v1, tracked paths, object IDs, and SHA-256 hashes for the tracked-file inventory.
- Record toolchain/runtime versions, dependency lock state, and environment details relevant to the claims.
- Run the baseline test suite and preserve raw output and exit status.
- Enumerate public interfaces, user-visible behavior, entry points, providers/consumers, side effects, persistent state, and integration boundaries.
- Inventory history across relevant refs/tags. Missing historical paths and renames must be classified from Git objects; filename similarity alone does not prove semantic equivalence.
- If no trustworthy baseline exists, remain BLOCKED and explicitly define the alternative baseline-creation decision. Do not silently call the candidate its own baseline.

### Phase 2 — Define the change contract

Before implementation, write the objective and non-goals; acceptance criteria; affected interfaces and integration surfaces; expected new behavior; existing behavior that must remain invariant; authorized removals, if any; failure modes and recovery requirements; and tests/evidence expected for each claim.

Every acceptance criterion must map to a test, direct observation, or explicit review decision.

### Phase 3 — Implement

- Prefer one coherent architecture and separate domain logic from orchestration and side effects.
- Use execution-first/EAFP where appropriate, with narrow exception handling and explicit classification of expected failures.
- Preserve existing behavior unless removal is explicitly approved.
- Keep operations deterministic and idempotent.
- Make persistent writes atomic or provide a tested rollback transaction.
- Do not claim atomicity if a multi-resource operation can leave a partial state.
- Avoid generic catch-all handlers that convert unknown failures to success or safe-looking defaults.
- Never replace a real integration test with a mock and then claim end-to-end proof.

### Phase 4 — Validate candidate

- Run formatting, static analysis, type/lint checks, unit tests, integration tests, and relevant end-to-end tests.
- Compare baseline and candidate paths, hashes, APIs, behavior, configuration, runtime wiring, dependency graph, and integration surfaces.
- Inspect both directions of every declared alignment: declaration-to-observation and observation-to-declaration; provider-to-consumer and consumer-to-provider.
- Validate history continuity and disposition every missing/changed path with evidence.
- Exercise failure, retry, interruption, recovery, and repeated execution for stateful paths.
- Run repository-required gates, including Golden Units and applicable O.M.A. gates.
- Do not mark an unavailable test as passed. Record it as BLOCKED with reason and scope.

### Phase 5 — Freeze evidence

Evidence must identify exact baseline and candidate commits. A release candidate must be committed and have a clean worktree. Hash evidence artifacts and preserve raw test outputs. The evidence validator must reject a dirty candidate, mismatched commit IDs, malformed hashes, incomplete semantic review, unresolved required surfaces, or a failing required test.

### Phase 6 — Review and release

- Produce a reviewable Git change with a clear commit message and pull request.
- Include behavior delta, validation commands/results, known limitations, rollback plan, and explicit capability-loss review.
- Do not merge based on a green unit suite alone if integration, continuity, or machine gates are required.
- After merge, verify the merge commit and rerun appropriate post-merge gates.
- Record the final immutable release commit and checksum manifest.

## Required status vocabulary

- **PASS** — the required claim was exercised and supported by valid evidence.
- **FAIL** — evidence demonstrates a contract violation or failed required gate.
- **BLOCKED** — evidence is missing, inconsistent, untrustworthy, or the required environment/gate was unavailable.
- **NOT APPLICABLE** — outside declared scope, with rationale and review.
- **AUTHORIZED RETIREMENT** — removal explicitly approved and recorded with owner, rationale, impact, and migration/recovery disposition.

Silence, skipped tests, and unavailable tooling are never PASS.

## Severity

- **CRITICAL:** data loss/corruption; unapproved validated feature loss; false success; broken security boundary; unrecoverable mutation; incomplete rollback; certified-baseline regression.
- **HIGH:** non-idempotent behavior; lifecycle/resource leak; race or concurrency corruption; unsupported-state mutation; reproducible integration failure; incomplete recovery.
- **MEDIUM/LOW:** classify by actual impact, scope, and recoverability. Severity may not be reduced merely to unblock a release.

## Completion gate

GUP is GREEN only when baseline and candidate identities are exact; candidate worktree is clean; inventories reconcile; history continuity has evidence-backed dispositions; semantic and integration reviews are complete; required tests and runtime observations pass; no unauthorized capability loss remains; required recovery/idempotency claims are exercised; and evidence is complete, hashed, reproducible, and validated.

Until then the project remains BLOCKED or FAIL.

## O.M.A. boundary

For this Arch/Hyprland repository, GUP repository-level certification does not imply machine-level assurance. Use the repository's GUP-O.M.A. skill and machine setup contract for declared hardware classes, real-machine tests, fault injection, recovery, and independent reproduction.

## Companion contracts

- Git substrate: GIT-SUBSTRATE.md
- Evidence contract: EVIDENCE-CONTRACT.md
- Operating procedure: OPERATING-PROCEDURE.md
- Gemini Markdown-only variant: GEMINI-MARKDOWN-ONLY.md

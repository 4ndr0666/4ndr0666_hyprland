# GUP v7 — Normative Protocol

## Status vocabulary

- PASS: the required claim was exercised and supported by valid evidence.
- FAIL: evidence demonstrates a contract violation or failed required gate.
- BLOCKED: evidence is missing, inconsistent, untrustworthy, or the required environment/gate is unavailable.
- NOT APPLICABLE: outside declared scope, with rationale and review.
- AUTHORIZED RETIREMENT: removal explicitly approved and documented with owner, rationale, impact, and migration/recovery disposition.

Silence, skipped tests, and unavailable tooling are never PASS.

## Lifecycle

### Identify

Verify canonical repository identity, intended root, Git availability, remotes, current ref, exact HEAD, and worktree status. Refuse accidental nested repositories unless explicitly intended. Setup must be idempotent and non-destructive.

### Baseline

Before mutation, capture exact baseline commit, tracked paths and blob IDs, SHA-256 inventory, worktree/index state, toolchain and dependency details, baseline tests and raw output, known defects, interfaces, active entrypoints, and relevant history. If there is no trustworthy baseline, remain BLOCKED until an explicit baseline-creation decision is recorded.

### Contract

Document objective, non-goals, acceptance criteria, invariants, affected interfaces, integration surfaces, authorized removals, failure modes, rollback, and tests. Map every criterion to real evidence.

### Implement

Use one coherent architecture. Separate domain logic from orchestration and side effects. Preserve supported behavior by default. Use narrow error handling; do not turn unknown errors into apparent success. Make writes atomic or use a tested recovery transaction. Do not claim atomicity for operations that can partially mutate state.

### Validate

Run all available static, unit, integration, end-to-end, negative-path, idempotency, recovery, repository, and applicable machine tests. Capture exact commands, environments, exit statuses, and output hashes. Label mocked tests as mocked. A test not run is BLOCKED or NOT RUN.

### Reconcile

Compare baseline and candidate paths, modes, hashes, interfaces, runtime wiring, dependencies, and observed behavior. Review both directions of declaration/observation and provider/consumer mappings. Classify missing historical paths as PRESERVED, TRANSLATED, AUTHORIZED_RETIRED, or UNRESOLVED. Unresolved in-scope behavior blocks full PASS.

### Freeze and release

Commit the candidate and verify a clean worktree. Tie evidence to exact baseline and candidate SHAs. Changes after evidence capture invalidate affected evidence. Review the behavior delta, test results, known limitations, capability-loss review, and rollback plan. After merge, identify the exact merge commit and rerun required gates.

## Completion gate

A full PASS requires exact baseline and candidate identities; clean candidate; reconciled inventories; evidence-backed history dispositions; complete semantic and integration review; all required tests passing; no unauthorized capability loss; exercised idempotency/recovery where relevant; and complete, consistent, reproducible evidence.

Git proves identity and lineage, not runtime correctness. Machine-specific claims require the applicable GUP-O.M.A. evidence.

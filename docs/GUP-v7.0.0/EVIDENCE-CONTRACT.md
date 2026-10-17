# GUP v7 — Evidence Contract

## Principle

Evidence must make the certification claim independently reproducible. An assertion without source output, exact revision identity, exit status, and a mapping to acceptance criteria is not proof.

## Required evidence record

Each run records at minimum:

| Field | Requirement |
| --- | --- |
| protocol_version | Exact GUP protocol version |
| repository | Canonical URL and root |
| baseline_commit | Full immutable Git commit SHA |
| candidate_commit | Full immutable Git commit SHA |
| worktree_clean | Must be true for certification |
| baseline_inventory_sha256 | SHA-256 of canonical inventory |
| candidate_inventory_sha256 | SHA-256 of canonical inventory |
| history_review | Complete dispositions for relevant historical paths |
| semantic_review | Reviewed behavior delta and feature-loss determination |
| alignment | Bidirectional declarations/observations and provider/consumer mapping |
| tests | Command, environment, exit status, raw-output hash, and result |
| recovery | Idempotency, interruption, rollback, and retry results where applicable |
| blocked_targets | Explicit list; must be empty for a full PASS |
| reviewer | Identity/role and review timestamp |
| final_status | PASS, FAIL, or BLOCKED |

Do not store secrets or unnecessary personal data in evidence.

## Hashing

Use SHA-256 for evidence and inventory artifacts. Hash the exact bytes retained. If output is normalized before hashing, document normalization and retain original output as well.

Never invent a hash, commit, exit code, test result, or reviewer approval. A checksum proves only that bytes match a digest; it does not prove semantic truth.

## Test record

For every required test, record the exact command and arguments; working directory and relevant environment; tool/runtime version; start/end time and exit status; raw stdout/stderr or a content-addressed artifact reference; SHA-256 digest of retained output; acceptance criteria covered; and PASS/FAIL/BLOCKED classification.

A command that was not run must be BLOCKED or NOT RUN, not PASS. A mocked test must be labelled as mocked and cannot stand in for a real integration claim.

## Reconciliation

The validator must fail closed when baseline/candidate SHA is missing, malformed, or inconsistent; candidate worktree is dirty; an inventory hash is malformed or cannot be recomputed; required test evidence is absent or nonzero; history or semantic review is incomplete; integration surfaces lack a disposition; a target is blocked while full certification is requested; or the evidence claims PASS while any required gate is not PASS.

## Semantic and integration review

Review behavior, not only file diffs. Inspect entry points and runtime wiring; configuration loaded by the actual active entrypoint; providers and consumers; public APIs and command-line interfaces; environment variables, startup commands, keybindings, services, hooks, and persistent state; dependencies, packaging, installation, and rollback; user-visible behavior and machine-specific paths.

Check both directions: every declared feature should be observed or explicitly unverified, and every observed behavior should have an accountable declaration/source. Every provider must have its consumers reviewed, and every consumer must resolve to a provider or documented external contract.

## Evidence invalidation

Changes to source, configuration, dependencies, environment assumptions, or test commands may invalidate evidence. Re-run affected gates after any candidate change. Post-merge evidence must identify the merge commit, not merely the pre-merge branch head.

## Certification statement

A valid final statement names the exact commit; scope and support envelope; gates actually executed; evidence locations and hashes; known limitations and blocked dimensions; and what is not being claimed.

Never claim universal correctness or unbounded hardware coverage from a finite test set.

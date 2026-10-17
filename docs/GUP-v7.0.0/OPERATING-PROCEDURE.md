# GUP v7 — Operating Procedure

## 1. Preflight

Run from the intended repository root:

- git rev-parse --show-toplevel
- git rev-parse --verify HEAD
- git status --porcelain=v1
- git remote -v
- git --version

Stop if root or repository identity is unexpected. Preserve intentional work before switching refs or updating files. Never use a destructive reset as generic cleanup.

## 2. Establish baseline

Capture exact HEAD SHA and symbolic ref; clean/dirty status; tracked path/blob inventory and SHA-256 inventory; current tests and raw output; relevant runtime/toolchain/dependency versions; historical paths across relevant refs/tags; and known defects/unsupported conditions.

If baseline is not trustworthy, record BLOCKED_BASELINE_NOT_ESTABLISHED. Do not self-certify against the candidate.

## 3. Declare the change

Map every requirement to one or more verification methods. Record affected interfaces, integration surfaces, persistent state, failure modes, rollback, and authorized retirements. No capability may be removed merely because it appears unused or because the new architecture is cleaner.

## 4. Implement safely

- Keep the architecture coherent and separate domain logic from orchestration.
- Prefer EAFP where it provides correct failure semantics; do not replace error handling with blind retries.
- Keep exception handling narrow and preserve original errors.
- Use atomic file replacement or explicit tested rollback for persistent changes.
- Ensure cleanup on success and failure; surface cleanup errors.
- Make repeated runs converge.
- Do not include unresolved placeholders in final artifacts.

## 5. Test in increasing scope

Run, as applicable: formatting/lint/type/static checks; unit tests; integration tests using real boundaries; end-to-end tests; negative/failure-path tests; repeated-run/idempotency tests; interruption and recovery tests; repository Golden Unit gates; and O.M.A. machine gates for claims involving supported Arch hardware/runtime.

Record actual command, exit status, and output digest for each. Mark unavailable checks BLOCKED.

## 6. Compare baseline and candidate

Reconcile added, modified, deleted, renamed, and mode-changed paths. Review semantic behavior independently of filenames. Review active configuration loading, startup/session wiring, dependencies, providers/consumers, external interfaces, and rollback.

Every missing historical path must be preserved, translated with evidence, authorized for retirement, or left unresolved. An unresolved in-scope path blocks a full PASS.

## 7. Freeze candidate and validate evidence

Commit the candidate. Confirm clean status. Tie every inventory, test, and review record to exact baseline and candidate commits. Validate checksums and evidence consistency. Any post-capture mutation requires relevant gates to rerun.

## 8. Review and merge

Create a pull request with objective and scope; baseline/candidate SHAs; behavior delta and capability-loss disposition; validation commands and actual outcomes; evidence links/hashes; known limitations and blocked gates; and rollback plan.

Merge only after required gates are green and reviewers have resolved material discrepancies. A successful merge is not proof that machine-level gates passed.

## 9. Post-merge

Fetch the target branch, identify the exact merge commit, confirm clean state, and rerun required post-merge gates. Update the release record and checksums. For O.M.A.-scoped changes, run the declared machine matrix and report only the level supported by evidence.

## 10. Incident/interruption

If a command, session, or host is interrupted: do not blindly rerun; inspect Git status, current commit, logs, and persistent state; identify completed and incomplete mutations; execute documented recovery; verify recovered state; rerun only after state is understood; retain failure evidence.

## Repository-specific gates

For this repository, at minimum run:

- bash ./install.sh --dry-run
- bash ./tests/unit/run-golden-units.sh

O.M.A. inventory and verification are additional machine-evidence gates, not replacements for repository-level tests. Do not claim an O.M.A. level unless its full required matrix and evidence contract are satisfied.

# GUP v7 — Evidence Record

Fill this record only with observed facts. The initial final status is BLOCKED.

## Run identity

- Protocol version: GUP v7.0.0
- Repository URL:
- Repository root:
- Baseline commit SHA:
- Candidate commit SHA:
- Branch/ref:
- Git version:
- Worktree clean: BLOCKED
- Baseline inventory location:
- Baseline inventory SHA-256:
- Candidate inventory location:
- Candidate inventory SHA-256:

## Review

- Historical path dispositions:
- Semantic behavior review:
- Declaration/observation alignment:
- Provider/consumer alignment:
- Capability-loss determination:
- Recovery/idempotency evidence:
- Known limitations:

## Test evidence

For every required test, record the exact command and arguments, working directory, relevant environment, tool/runtime version, exit status, raw output location, raw-output SHA-256, acceptance criteria covered, and result.

| Check | Command | Exit status | Output SHA-256 | Result |
| --- | --- | --- | --- | --- |
| Static/lint/type | | | | BLOCKED |
| Unit tests | | | | BLOCKED |
| Integration tests | | | | BLOCKED |
| End-to-end tests | | | | BLOCKED |
| Idempotency/recovery | | | | BLOCKED |
| Repository Golden Units | | | | BLOCKED |
| Applicable O.M.A. gates | | | | BLOCKED |

Add or remove rows only with a documented scope rationale. Do not represent unavailable checks as passing.

## Certification

- Blocked gates:
- Reviewer and review timestamp:
- Final status: BLOCKED

A PASS requires every mandatory gate to have real evidence tied to the exact candidate commit, a clean worktree, reconciled history and behavior, and no unapproved capability loss. Never invent hashes, commits, output, exit codes, or approvals. Hashes prove byte integrity, not semantic truth.

# GUP v7 — Final Review Checklist

Mark a box only after inspecting actual evidence.

- [ ] Canonical repository identity and intended root verified.
- [ ] Exact baseline commit established before mutation.
- [ ] Baseline tests and known defects recorded.
- [ ] Baseline/candidate inventories and hashes are reproducible.
- [ ] Candidate commit SHA is exact and worktree is clean.
- [ ] Acceptance criteria map to actual tests or explicit review decisions.
- [ ] Runtime entrypoints and active configuration loading inspected.
- [ ] Providers and consumers reconcile in both directions.
- [ ] Every relevant historical missing path has an evidence-backed disposition.
- [ ] No unapproved capability loss remains.
- [ ] Required static, unit, integration, end-to-end, negative-path, and recovery checks were run.
- [ ] Every test has an actual command, exit status, output reference, and hash.
- [ ] Mocked tests are labelled and not used as proof of real integration.
- [ ] Idempotency, interruption, cleanup, and rollback are exercised where applicable.
- [ ] Evidence records identify exact baseline and candidate SHAs.
- [ ] No secrets or unnecessary personal data are present in evidence.
- [ ] Known limitations and blocked checks are explicit.
- [ ] Repository Golden Unit gates passed.
- [ ] Applicable O.M.A. machine gates passed for any machine-level claim.
- [ ] Post-merge checks identify and validate the merge commit.
- [ ] Final status agrees with all individual results.

## Decision

- PASS: every mandatory check is supported by valid evidence.
- FAIL: a required check demonstrates a contract violation.
- BLOCKED: any mandatory evidence is missing, inconsistent, or unavailable.

Never convert an unchecked box to a pass based on expectation or narrative.

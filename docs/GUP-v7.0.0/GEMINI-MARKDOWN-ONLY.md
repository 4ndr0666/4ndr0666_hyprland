# GUP v7 — Markdown-Only Agent Variant

## Purpose and format constraint

This variant is intended for environments where agent instructions must be Markdown documents and executable helper scripts are not accepted. It preserves the same proof requirements as the standard protocol; it does not pretend that prose performs a machine check.

## Mandatory rule

If a required check cannot actually be executed in the current environment, record it as BLOCKED and identify the exact missing capability. Never fabricate command output, hashes, commits, test results, approvals, or successful mutations.

## Git-first sequence

1. Identify the repository root, canonical remote, current branch/ref, exact HEAD SHA, and worktree state.
2. Establish and record a trustworthy baseline before editing.
3. Inventory tracked paths, blob IDs, content hashes, interfaces, active entry points, dependencies, providers/consumers, and relevant history.
4. Declare acceptance criteria and behavior that must remain invariant.
5. Implement a coherent change without unauthorized capability loss.
6. Execute all available tests and inspect actual output and exit statuses.
7. Compare baseline to candidate, including historical paths and semantic behavior.
8. Commit the candidate and require a clean worktree.
9. Reconcile evidence with exact baseline and candidate SHAs.
10. Report PASS only when every required gate has real supporting evidence.

## Evidence record (fill only from observed facts)

- Protocol: GUP v7.0.0
- Repository URL:
- Repository root:
- Baseline commit SHA:
- Candidate commit SHA:
- Git version:
- Worktree clean: PASS / FAIL / BLOCKED
- Baseline inventory and SHA-256:
- Candidate inventory and SHA-256:
- Historical continuity dispositions:
- Semantic behavior review:
- Declaration/observation alignment:
- Provider/consumer alignment:
- Tests executed and exit statuses:
- Idempotency/recovery evidence:
- Known limitations:
- Blocked gates:
- Final status: BLOCKED

The initial status is BLOCKED. Change it only after checking every required gate against actual evidence.

## Review checklist

- [ ] Exact repository and commit identities recorded.
- [ ] Baseline existed before implementation and was independently identified.
- [ ] Candidate worktree is clean.
- [ ] No unapproved feature/capability loss.
- [ ] Historical missing paths have evidence-backed dispositions.
- [ ] Active runtime entrypoints and configuration loading were inspected.
- [ ] Providers and consumers reconcile in both directions.
- [ ] All required tests have real command output and exit status.
- [ ] Repeated execution converges for stateful operations.
- [ ] Failure/interruption/recovery paths are exercised where required.
- [ ] Evidence hashes and commit references reconcile.
- [ ] Blocked dimensions and untested claims are explicit.
- [ ] Final status is consistent with every individual result.

## Limitations

Markdown instructions can direct an agent to execute Git and test commands, structure a review, and report observed evidence. They cannot guarantee that the environment executed a command, that output is authentic, or that a mutation was atomic. Those claims require real execution and independent verification. When tools are unavailable, the correct result is BLOCKED, not a prose simulation of PASS.

## Normative companion documents

Use the GUP v7 core protocol, Git substrate, evidence contract, and operating procedure in this directory. For machine-specific Arch/Hyprland claims, also use the repository's GUP-O.M.A. contract.

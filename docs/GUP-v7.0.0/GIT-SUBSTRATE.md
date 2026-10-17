# GUP v7 — Git Substrate Contract

## Purpose

Git is the authoritative substrate for project identity, immutable baseline/candidate references, path history, change review, and evidence provenance. Filesystem timestamps, branch names alone, screenshots, and conversational summaries are not substitutes for Git object identity.

## Identity requirements

Every run records the canonical repository URL and root; exact baseline commit SHA; exact candidate commit SHA; symbolic branch/ref and relevant fetched ref tips; Git version; worktree/index status; tracked path inventory and content hashes; submodule state; and LFS pointer/object state where used.

A branch name is mutable. The commit SHA is the immutable identity.

## Bootstrap rules

1. Inspect the intended root and existing Git metadata before initialization.
2. If a repository exists, reuse it; do not create a nested repository.
3. If it does not exist, initialize only after confirming the intended root.
4. Initialization is idempotent and non-destructive.
5. Never overwrite existing .gup metadata. Reconcile it explicitly.
6. Do not stage, commit, switch branches, rewrite history, or change global Git configuration as a side effect of bootstrap.
7. Write initial project metadata atomically and set status to BLOCKED_BASELINE_NOT_ESTABLISHED.
8. Keep secrets, tokens, credentials, and private machine data out of manifests and evidence.

## Inventory

The inventory distinguishes tracked paths and Git blob IDs; SHA-256 of current file bytes where available; untracked files; ignored files relevant to the project contract; submodules and external dependencies; symlinks and executable bits; and clean versus dirty index/worktree.

Baseline and candidate inventories are compared as sets and by content. A file disappearing from the current tree is not automatically a feature loss, but it must receive an evidence-backed disposition. Backup/archive naming is not proof that the content is irrelevant.

## History continuity

Build the historical path inventory from Git objects across explicitly fetched refs and relevant tags. For each relevant historical path, record first/last observed commit and blob IDs; rename/copy events when supported by Git history; current disposition; and evidence supporting translation, preservation, or authorized retirement.

Allowed dispositions:
- PRESERVED: behavior remains present and is validated.
- TRANSLATED: behavior moved or transformed, with semantic mapping and tests.
- AUTHORIZED_RETIRED: removal explicitly approved and documented.
- UNRESOLVED: insufficient evidence; blocks certification for in-scope behavior.

Do not infer semantic equivalence from equal filenames, comments, backups, or superficial text similarity. Do not treat archival copies as live behavior, but preserve and classify them honestly.

## Candidate freeze

A certifiable candidate is represented by an exact commit, has a clean index and worktree, has all required evidence tied to that exact commit, and has no post-evidence edits.

Any change after evidence capture invalidates affected evidence and requires relevant gates to rerun.

## Branch and review policy

Use a reviewable feature branch and pull request. Avoid force-push/history rewriting unless specifically authorized and operationally justified. The PR states baseline SHA, candidate SHA, behavior delta, test commands/results, known limitations, and rollback strategy.

## Integrity and recovery

Hash evidence artifacts with SHA-256. Preserve raw command output, exit status, and tool versions. If an operation is interrupted, inspect repository state and persistent state before retrying. Never assume a failed command made no changes.

## Git is necessary, not sufficient

Git proves object identity and change lineage; it does not by itself prove runtime behavior. GUP combines Git provenance with semantic review, real tests, integration alignment, idempotency/recovery exercises, and machine evidence where required.

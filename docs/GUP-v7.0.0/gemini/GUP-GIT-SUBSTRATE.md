# GUP v7 — Git Substrate

Git is the source of truth for repository identity, baseline and candidate states, history, review, and evidence provenance. Branch names are mutable; full commit SHAs identify immutable objects.

## Required identity

Record canonical repository URL/root, baseline SHA, candidate SHA, branch/ref, relevant fetched refs, Git version, index/worktree state, tracked path inventory, content hashes, submodule state, and LFS state where applicable.

## Safe bootstrap

- Inspect the intended root and existing repository metadata first.
- Reuse an existing repository; do not create nested repositories accidentally.
- Initialize only in the explicitly intended root.
- Make repeated initialization idempotent and non-destructive.
- Do not overwrite existing project metadata; reconcile it explicitly.
- Do not stage, commit, switch branches, rewrite history, or change global Git configuration implicitly.
- Start metadata in BLOCKED_BASELINE_NOT_ESTABLISHED.
- Keep secrets out of manifests and evidence.

## Inventory and continuity

Compare baseline and candidate path sets, blob IDs, hashes, modes, symlinks, and relevant untracked/ignored state. Build historical path inventory from Git objects across relevant refs/tags. Record first/last observed commits, blob IDs, renames when supported by history, disposition, and supporting evidence.

Allowed dispositions:
- PRESERVED: behavior remains present and validated.
- TRANSLATED: behavior moved or transformed, with semantic mapping and tests.
- AUTHORIZED_RETIRED: explicitly approved and documented removal.
- UNRESOLVED: insufficient evidence; blocks certification for in-scope behavior.

Archive names and filename similarity do not prove behavior is preserved or irrelevant.

## Candidate freeze

A certifiable candidate is committed, has a clean index/worktree, and has evidence tied to exact baseline and candidate SHAs. Any later mutation invalidates affected evidence and requires relevant checks to rerun.

## Recovery

After interruption or command failure, inspect Git and persistent state before retrying. Never assume a failed command made no changes. Preserve raw output and exit status. Git is necessary but not sufficient: semantic review and real runtime tests remain required.

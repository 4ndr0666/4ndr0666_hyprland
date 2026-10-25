# GUP Rehydration Verification

## Purpose

The script scripts/gup_rehydration_verify.py builds a reproducible continuity report from Git objects. It does not accept an illustrative commit as its authority: the commit graph is discovered from HEAD and every reachable repository ref. Use a complete clone (fetch-depth: 0) for certification; shallow history is a hard failure.

The default scope is config/hypr. Use --scope to select another repository-relative path. The report is generated on demand and preserved as a GitHub Actions artifact; it is not a hand-maintained replacement for the committed disposition manifest.

## Run

Generate the inventory without failing on unresolved active paths:

    python3 scripts/gup_rehydration_verify.py \
      --scope config/hypr \
      --dispositions docs/audits/gup-history-continuity-dispositions.json \
      --output /tmp/gup-rehydration-verification.json

Run the strict gate:

    python3 scripts/gup_rehydration_verify.py \
      --scope config/hypr \
      --dispositions docs/audits/gup-history-continuity-dispositions.json \
      --strict \
      --output /tmp/gup-rehydration-verification.json

The strict gate fails on historical paths without an evidence-backed disposition or when the repository is shallow. Missing commits, trees, or blobs fail closed when Git cannot traverse or read them. The CI workflow additionally fails if any active unresolved paths remain.

## Evidence contract

Schema version 3 records metadata for every commit reachable from the accepted refs, and a complete scoped path-state snapshot for each commit that changes the selected scope. Commits that do not change the scope are not duplicated as path-state snapshots; `scope_state_commits` names the exact snapshot set. Each path-version record contains the commit, path, mode, Git blob object ID, and a `git_show_spec` such as `COMMIT:path`. Anyone with the repository objects can independently reconstruct that state with `git show COMMIT:path`. The full commit metadata and native object pins remain present even for commits outside the scoped state set.

The tool enumerates every object reachable from `HEAD`, `refs/heads/*`, `refs/tags/*`, and `refs/remotes/*`, excluding `refs/stash`. The enumeration includes commits, all nested trees, all blobs (including blobs outside the selected path scope), and annotated tag objects. Tag targets are followed so nested annotated tags are not omitted. Exact object payloads are streamed through Git's batch object interface; the tool recomputes each repository-native object ID using Git's object framing (`TYPE SIZE NUL PAYLOAD`) and the repository's declared hash algorithm, and computes a separate SHA-256 digest over each payload. The stream is hashed incrementally rather than retaining the full object graph in memory. A report is invalid if an object is missing, a recomputed Git object ID differs, the returned type conflicts with a known commit/root-tree/scoped-blob type, or the object stream is malformed. `object_pins` covers the complete accepted reachable object set; `blob_pins` intentionally remains scoped to historical configuration blobs for compatibility with prior reports.

The disposition manifest is read from HEAD using Git plumbing, not from a potentially modified working-tree copy. Its Git object ID and SHA-256 are included in the report. preserved and translated dispositions require a current tracked target; authorized-retired requires explicit authorization and rejects a path still present at HEAD. The report preserves the supporting evidence text from the committed manifest.

## Interpretation limits

- present-path proves that the same path exists at HEAD; it does not by itself prove behavioral equivalence.
- preserved and translated are reviewed manifest classifications, not automatic conclusions from filename similarity.
- authorized-retired records explicit retirement authorization; it does not claim semantic equivalence.
- Path names and suffixes never establish retirement. Archive-, backup-, and generated-temp-named paths remain active continuity records and block strict certification when missing unless the committed evidence manifest explicitly authorizes retirement or identifies a current target.
- unresolved-missing means an active historical path has no current path and no accepted disposition. Strict mode blocks certification on this status.
- A green run proves object recomputation and path-disposition gate coverage for the refs fetched in that run. It does not certify live compositor behavior or other runtime surfaces outside the selected scope.

The report includes metadata for every reachable commit and recomputable pins for every object reachable from the accepted refs, while scoped path versions are recorded only at scope-changing commits. The `reachable_object_type_counts` field separates commit, tree, blob, and tag totals; `verification.all_reachable_objects_pinned` asserts that every enumerated object has a corresponding pin. This avoids repeating identical path states for unrelated commits while preserving every transition that can change the selected scope. Store the artifact with the associated CI run and recompute it from the same Git object database when independent verification is required.

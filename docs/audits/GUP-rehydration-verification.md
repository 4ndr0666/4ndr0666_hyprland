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

For each reachable commit, the report records commit metadata and every blob path state within scope. Each path-version record contains the commit, path, mode, Git blob object ID, and a git_show_spec such as COMMIT:path. Anyone with the repository objects can independently reconstruct that state with git show COMMIT:path.

For each reachable commit, its root tree, and every unique historical blob in scope, the tool reads the object payload from Git, recomputes the repository's native object ID with git hash-object -t TYPE --stdin, and computes a separate SHA-256 digest over the exact payload bytes. A report is invalid if a recomputed Git object ID differs from the recorded ID. This pins commit identity, complete commit-tree identity, and scoped file content with both Git-native object IDs and SHA-256 digests.

The disposition manifest is read from HEAD using Git plumbing, not from a potentially modified working-tree copy. Its Git object ID and SHA-256 are included in the report. preserved and translated dispositions require a current tracked target; authorized-retired requires explicit authorization and rejects a path still present at HEAD. The report preserves the supporting evidence text from the committed manifest.

## Interpretation limits

- present-path proves that the same path exists at HEAD; it does not by itself prove behavioral equivalence.
- preserved and translated are reviewed manifest classifications, not automatic conclusions from filename similarity.
- authorized-retired records explicit retirement authorization; it does not claim semantic equivalence.
- Path names and suffixes never establish retirement. Archive-, backup-, and generated-temp-named paths remain active continuity records and block strict certification when missing unless the committed evidence manifest explicitly authorizes retirement or identifies a current target.
- unresolved-missing means an active historical path has no current path and no accepted disposition. Strict mode blocks certification on this status.
- A green run proves object recomputation and path-disposition gate coverage for the refs fetched in that run. It does not certify live compositor behavior or other runtime surfaces outside the selected scope.

Because the report includes all reachable commit/path versions, it can be large. Store the artifact with the associated CI run and recompute it from the same Git object database when independent verification is required.

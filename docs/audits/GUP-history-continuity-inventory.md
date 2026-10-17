# GUP historical configuration continuity inventory

## Purpose

The repository's Git commit trees are the reproducible source for historical configuration paths. This inventory reconstructs path-to-blob relationships from snapshots at commits reachable from local refs. It does not rely on a supplied archive, conversation history, or a hand-selected commit SHA.

Run from a complete clone:

```sh
python3 scripts/gup-history-continuity.py --output /tmp/gup-history-continuity.json
```

To include reviewed dispositions:

```sh
python3 scripts/gup-history-continuity.py \
  --dispositions docs/audits/gup-history-continuity-dispositions.json \
  --output /tmp/gup-history-continuity.json
```

The report includes commit identities, path-specific historical blob IDs, rename events detected by Git's similarity-based rename detection, candidate HEAD, ref tips, and worktree state. It distinguishes **path continuity** from **behavioral equivalence**. A current file at the same path is only marked `present-path`; that does not prove that its former behavior survived.

## Dispositions and strict mode

A JSON disposition manifest may contain exact path dispositions and/or an `authorized_subtrees` array. Allowed exact-path statuses are:

- `preserved`: evidence identifies the current target where the behavior remains available.
- `translated`: evidence identifies the replacement target.
- `authorized-retired`: explicit authorization and evidence support retirement.

Every disposition requires non-empty `evidence`. `preserved` and `translated` require a `target` path that is tracked in candidate HEAD. `authorized-retired` requires `user_authorization: true`. Dispositions for unknown, out-of-scope, or currently present paths are rejected.

An authorized subtree entry must identify a strict descendant of the requested scope, use `status: authorized-retired`, include non-empty evidence, and set `user_authorization: true`. The subtree must contain historical paths and no currently tracked paths. Each matching historical path is expanded into an individual disposition record in the output. Overlapping subtree/path dispositions fail closed.

The checked-in manifest `docs/audits/gup-history-continuity-dispositions.json` records the user's explicit authorization to retire `config/hypr/LEGACY_CODE`. It does not claim that every path was behaviorally translated or that the subtree is semantically equivalent to the active configuration. This authorization applies only to that subtree; other missing active paths remain unresolved.

Example of an exact path disposition:

```json
{
  "config/hypr/UserConfigs/Legacy.conf": {
    "status": "translated",
    "target": "config/hypr/UserConfigs/Legacy.lua",
    "evidence": "tests/unit/test-legacy-config-translation.sh validates the migrated behavior"
  }
}
```

Do not populate dispositions from filename similarity alone. The example is illustrative and is not a project disposition.

Use `--strict` to return status 1 if any active in-scope historical path remains unresolved. Git errors, invalid manifests, and I/O failures return status 2. The strict gate is deliberately not wired into CI until the remaining inventory is reviewed; this avoids either breaking CI indiscriminately or encouraging unsupported blanket exemptions.

## Scope and limitations

- Scope defaults to `config/hypr`; pass `--scope` to inventory another subtree. Unsafe absolute paths and parent traversal are rejected.
- All refs present in the clone are included. Fetch all relevant branches/tags before relying on the report.
- Archive-like paths are retained in the report as `archive-path-present`, `archive-path-missing`, or `authorized-retired`. Archive classification does not prove their behavior is irrelevant or preserved.
- Historical paths are reconstructed from commit tree snapshots, not from a de-duplicated object listing. This preserves distinct paths that happen to share the same blob ID.
- The inventory is path/object evidence, not a semantic parser. Renames and translations must be reviewed with diffs and behavioral tests.
- The report records current HEAD, ref tips, and worktree state. It does not claim that the clone contains refs not fetched into it.

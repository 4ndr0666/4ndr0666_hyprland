# GUP historical configuration continuity inventory

## Purpose

The repository's Git object database is the reproducible source for historical configuration paths. This inventory reconstructs paths and object IDs reachable from local refs without depending on a supplied archive, conversation history, or a hand-selected commit SHA.

Run from a complete clone:

```sh
python3 scripts/gup-history-continuity.py --output /tmp/gup-history-continuity.json
```

The report intentionally distinguishes **path continuity** from **behavioral equivalence**. A current file at the same path is only marked `present-path`; its presence does not prove that its former behavior survived. Missing paths outside obvious backup/archive directories are `unresolved-missing` unless an evidence-backed disposition is supplied.

## Dispositions and strict mode

A JSON disposition manifest is keyed by the exact historical repository path. Allowed statuses are:

- `preserved`: evidence shows the behavior remains available.
- `translated`: evidence identifies a replacement `target`.
- `authorized-retired`: explicit authorization and evidence support retirement.

Every disposition requires non-empty `evidence`. Translation requires a `target`. Example:

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

Use `--strict` to return status 1 if any in-scope historical path remains unresolved. Git errors, invalid manifests, and I/O failures return status 2. The strict gate is deliberately not wired into CI until the initial inventory is reviewed and every genuine capability loss is dispositioned; wiring it before that review would either break CI indiscriminately or encourage unsupported blanket exemptions.

## Scope and limitations

- Scope defaults to `config/hypr`; pass `--scope` to inventory another subtree.
- All refs present in the clone are included. Fetch all relevant branches/tags before relying on the report.
- Common backup/archive path patterns are excluded from the unresolved-path gate, but remain represented by Git history and can be audited separately.
- The inventory is path/object evidence, not a semantic parser. Renames and translations must be reviewed with diffs and behavioral tests.
- The report records the current HEAD and ref tips to make each run reproducible. It does not claim that the clone contains refs not fetched into it.

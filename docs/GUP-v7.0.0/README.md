# GUP v7.0.1 — Core Protocol Documents & Executable Toolchain

This directory versions the repository-owned GUP v7 protocol contracts for project identity, Git provenance, evidence, review, and release validation. Platform-specific actionable skill files are maintained as private deliverables and are intentionally excluded from this public repository.

## Document map

- [GIT-SUBSTRATE.md](GIT-SUBSTRATE.md) — repository identity, idempotent bootstrap, inventories, history continuity, and candidate freeze.
- [EVIDENCE-CONTRACT.md](EVIDENCE-CONTRACT.md) — evidence schema requirements, hashing, reconciliation, and invalidation.
- [OPERATING-PROCEDURE.md](OPERATING-PROCEDURE.md) — operator sequence from preflight through post-merge verification.

## Vendored executable toolchain

- `golden_unit_hash.py` — AST/lexical unit inventory and structural hash comparison engine (Python, JS/TS, Bash, plus `--manual-units`).
- `scripts/gup_init.py` — idempotent Git + `.gup/project.json` bootstrap.
- `scripts/gup_inventory.py` — tracked worktree SHA-256 inventory and cleanliness gate.
- `scripts/gup_history_continuity.py` and `scripts/gup-history-continuity.py` — historical Git path continuity and disposition gates.
- `scripts/gup_rehydration_verify.py` — repository-derived commit/path/blob history, recomputed Git object IDs and SHA-256 pins, rename evidence, and fail-closed active-path continuity verification.
- `scripts/gup_alignment.py` — bidirectional declaration/observation and provider/consumer alignment verifier (`schemas/gup-alignment.schema.json`).
- `scripts/gup_validate.py` — fail-closed release evidence validator (`schemas/gup-evidence.schema.json`).
- `tests/test_gup_tools.py`, `tests/test_gup_rehydration_verify.py`, and `tests/unit/test-gup-v7-toolchain.sh` — automated synthetic Git, rehydration integrity, and toolchain integration regression suites.
- [Rehydration verification evidence contract](../audits/GUP-rehydration-verification.md) — reproducible evidence fields, invocation, and interpretation boundaries.

## Relationship to existing assurance

GUP v7 defines repository-level correctness and evidence provenance. The repository's GUP-O.M.A. specification remains authoritative for machine-level claims involving Arch Linux, Hyprland, GPUs, drivers, display/session topology, fault injection, recovery, and independent reproduction.

## Required repository gates

For changes in this repository, run the actual commands and preserve their output:

- `bash ./install.sh --dry-run`
- `bash ./tests/unit/run-golden-units.sh`

These commands are not executed by reading this document. Record actual exit statuses and output hashes. Add O.M.A. machine gates when the claim or change touches the declared machine support envelope.

## Integration status

Both the GUP v7 protocol documentation and the companion standalone executable toolchain (`golden_unit_hash.py`, `scripts/gup_*.py`, `schemas/*.json`, `tests/test_gup_tools.py`, `tests/test_gup_rehydration_verify.py`) are vendored in this repository and enforced by `tests/unit/test-gup-v7-toolchain.sh` inside `tests/unit/run-golden-units.sh`.

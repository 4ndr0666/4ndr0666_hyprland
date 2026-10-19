# Changelog — GUP v7.0.1

## Added (v7.0.1)

- Vendored the complete GUP v7.0.1 executable Python toolchain (`golden_unit_hash.py`, `scripts/gup_init.py`, `scripts/gup_inventory.py`, `scripts/gup_history_continuity.py`, `scripts/gup_alignment.py`, `scripts/gup_validate.py`), JSON schemas (`schemas/gup-alignment.schema.json`, `schemas/gup-evidence.schema.json`), and synthetic Git test suite (`tests/test_gup_tools.py`).
- Added `tests/unit/test-gup-v7-toolchain.sh` to `tests/unit/run-golden-units.sh` to enforce `golden_unit_hash.py --selftest` and `tests/test_gup_tools.py` on every Golden Unit run.

## Added (v7.0.0)

- Git-first project identity and immutable baseline/candidate commit requirements.
- Idempotent, non-destructive bootstrap contract.
- Baseline/candidate inventory and historical path-continuity requirements.
- Evidence-backed dispositions for preserved, translated, authorized-retired, and unresolved paths.
- Bidirectional declaration/observation and provider/consumer alignment.
- Fail-closed evidence status vocabulary and release completion gate.
- Atomicity/recovery, idempotency, clean-candidate, and post-merge verification requirements.
- Explicit boundary between repository-level GUP and machine-level GUP-O.M.A.
- Explicit separation between public repository documentation and private platform-specific actionable skill deliverables.

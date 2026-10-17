# GUP v7.0.0 — Core Protocol Documents

This directory versions the normative GUP v7 project-start, Git provenance, evidence, review, and Markdown-only agent contracts.

## Document map

- [SKILL.md](SKILL.md) — normative lifecycle and completion gate.
- [GIT-SUBSTRATE.md](GIT-SUBSTRATE.md) — repository identity, idempotent bootstrap, inventories, history continuity, and candidate freeze.
- [EVIDENCE-CONTRACT.md](EVIDENCE-CONTRACT.md) — evidence schema requirements, hashing, reconciliation, and invalidation.
- [OPERATING-PROCEDURE.md](OPERATING-PROCEDURE.md) — operator sequence from preflight through post-merge verification.
- [GEMINI-MARKDOWN-ONLY.md](GEMINI-MARKDOWN-ONLY.md) — Markdown-only agent variant with an explicit BLOCKED default when checks cannot be executed.

## Relationship to existing assurance

GUP v7 defines repository-level correctness and evidence provenance. The repository's GUP-O.M.A. specification remains authoritative for machine-level claims involving Arch Linux, Hyprland, GPUs, drivers, display/session topology, fault injection, recovery, and independent reproduction.

## Required repository gates

For changes in this repository, run the actual commands and preserve their output:

- bash ./install.sh --dry-run
- bash ./tests/unit/run-golden-units.sh

These commands are not executed by reading this document. Record actual exit statuses and output hashes. Add O.M.A. machine gates when the claim or change touches the declared machine support envelope.

## Integration status

This directory is the protocol/documentation portion of GUP v7.0.0. The companion standalone standard package contains executable bootstrap, inventory, history-continuity, alignment, evidence-validation, and regression-test tooling. Those executable assets are not yet vendored by this documentation-only change; they must be integrated and tested as a separate reviewable change before the repository can claim the complete v7 toolchain is landed.

No certification or O.M.A. level is implied by the presence of these documents.

# Changelog — GUP v7.0.0

## Added

- Git-first project identity and immutable baseline/candidate commit requirements.
- Idempotent, non-destructive bootstrap contract.
- Baseline/candidate inventory and historical path-continuity requirements.
- Evidence-backed dispositions for preserved, translated, authorized-retired, and unresolved paths.
- Bidirectional declaration/observation and provider/consumer alignment.
- Fail-closed evidence status vocabulary and release completion gate.
- Atomicity/recovery, idempotency, clean-candidate, and post-merge verification requirements.
- Markdown-only Gemini variant that prohibits fabricated command output and requires BLOCKED when execution is unavailable.
- Explicit boundary between repository-level GUP and machine-level GUP-O.M.A.

## Not included in this documentation change

The companion standalone package's executable Python tooling and synthetic Git tests are not yet vendored in the repository. The protocol README records this limitation so the documentation is not mistaken for a complete executable toolchain.

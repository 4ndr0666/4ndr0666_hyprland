# GUP v7 — Gemini Markdown-Only Skill Package

This directory is the self-contained Markdown-only skill package. It intentionally contains no executable scripts, JSON schemas, binaries, or non-Markdown helper files.

## Package files

- SKILL.md — standard skill entrypoint with YAML frontmatter.
- GUP-PROTOCOL.md — lifecycle and completion requirements.
- GUP-GIT-SUBSTRATE.md — Git identity and history-continuity contract.
- GUP-EVIDENCE-RECORD.md — evidence fields, hashing, and fail-closed rules.
- GUP-REVIEW-CHECKLIST.md — final certification checklist.

## Important limitation

Markdown can instruct an agent to execute and inspect real checks, but cannot itself guarantee execution, authenticity, atomicity, or correctness. If a required tool or test is unavailable, the correct status is BLOCKED. Never simulate PASS.

This package describes the same evidence standard as the standard GUP package. It does not replace executable validation tooling or the machine-specific GUP-O.M.A. gates.

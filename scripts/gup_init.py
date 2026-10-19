#!/usr/bin/env python3
"""Idempotently establish Git as the project substrate and create GUP metadata.

Paradigm: Python standard-library transaction coordinator over Git CLI.
The initializer never stages, commits, resets, checks out, or overwrites user data.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

VERSION = "7.0.0"
SURFACES = [
    "entry_points", "loaders", "callers", "providers", "consumers",
    "configuration_paths", "install_migration_paths", "tests", "runtime_dependencies",
]


def run_git(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(root), *args], text=True, encoding="utf-8",
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=30,
    )


def atomic_create(path: Path, data: bytes) -> bool:
    """Create a new file without clobbering existing state; return whether created."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        try:
            # link() is atomic and fails if the destination already exists.
            os.link(temporary, path)
            try:
                dfd = os.open(path.parent, os.O_RDONLY)
                try: os.fsync(dfd)
                finally: os.close(dfd)
            except BaseException:
                path.unlink(missing_ok=True)
                raise
            return True
        except FileExistsError:
            return False
    finally:
        temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="project directory (default: current directory)")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    root.mkdir(parents=True, exist_ok=True)
    git_dir = run_git(root, "rev-parse", "--git-dir")
    initialized_here = False
    created: list[Path] = []
    try:
        if git_dir.returncode != 0:
            init = run_git(root, "init", "--initial-branch=main")
            if init.returncode != 0:
                raise RuntimeError(f"git init failed: {init.stderr.strip()}")
            initialized_here = True
        else:
            top = run_git(root, "rev-parse", "--show-toplevel")
            if top.returncode != 0 or Path(top.stdout.strip()).resolve() != root:
                raise RuntimeError("requested project root is inside another Git worktree; initialize GUP at the actual repository root")

        metadata = root / ".gup" / "project.json"
        manifest = {
            "protocol": "GUP",
            "protocol_version": VERSION,
            "repository_root": ".",
            "canonical_baseline": None,
            "candidate_commit": None,
            "state": "BLOCKED_BASELINE_NOT_ESTABLISHED",
            "required_integration_surfaces": SURFACES,
            "policy": {
                "git_is_authority": True,
                "uncommitted_state_can_never_be_certified": True,
                "capability_loss_requires_explicit_user_authorization": True,
                "hashes_are_not_semantic_proof": True,
            },
        }
        payload = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
        if atomic_create(metadata, payload):
            created.append(metadata)
        else:
            try:
                existing = json.loads(metadata.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as exc:
                raise RuntimeError(f"existing GUP metadata is unreadable; preserved without modification: {exc}") from exc
            if not isinstance(existing, dict) or existing.get("protocol") != "GUP" or existing.get("protocol_version") != VERSION:
                raise RuntimeError("existing GUP metadata belongs to another/invalid schema; preserved without modification; explicit migration is required")
        print(f"GUP {VERSION} substrate ready: {root}")
        print(f"metadata={metadata.relative_to(root)}")
        print("certification=BLOCKED until baseline, candidate, evidence, and tests are established")
        print("existing files and Git history were not overwritten; no commit was created")
        return 0
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        for path in reversed(created):
            path.unlink(missing_ok=True)
        if initialized_here:
            # Remove only the .git directory created by this invocation. If Git created
            # metadata elsewhere, refuse cleanup rather than guessing at its location.
            detected = run_git(root, "rev-parse", "--git-dir")
            if detected.returncode == 0:
                candidate = Path(detected.stdout.strip())
                if not candidate.is_absolute():
                    candidate = root / candidate
                if candidate.resolve() == (root / ".git").resolve():
                    import shutil
                    shutil.rmtree(candidate)
        print(f"GUP initialization failed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

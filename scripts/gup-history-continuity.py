#!/usr/bin/env python3
"""Inventory historical paths from committed Git trees without inferring semantic equivalence.

Every historical path remains visible in the report. Path names do not prove that a file
is archival or behaviorally irrelevant. Strict mode fails on every unresolved missing path
unless the committed evidence manifest explicitly classifies it.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

DEFAULT_SCOPE = "config/hypr"


def git(root: Path, *args: str) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=180,
    )
    if result.returncode:
        message = result.stderr.decode("utf-8", "replace").strip()
        raise RuntimeError(message or f"git {' '.join(args)} failed with status {result.returncode}")
    return result.stdout


def validate_scope(scope: str) -> str:
    if (not isinstance(scope, str) or not scope or scope.startswith("/") or scope.endswith("/")
            or "\\" in scope or any(part in {"", ".", ".."} for part in scope.split("/"))):
        raise ValueError("scope must be a non-empty repository-relative path without dot segments")
    return scope


def validate_repo_path(path: str, label: str) -> str:
    if (not isinstance(path, str) or not path or path.startswith("/") or "\\" in path
            or any(part in {"", ".", ".."} for part in path.split("/"))):
        raise ValueError(f"invalid repository-relative {label}: {path!r}")
    return path


def read_dispositions(root: Path, manifest: str | None, scope: str,
                      historical: dict[str, set[str]], current: set[str]) -> dict[str, dict[str, Any]]:
    if manifest is None:
        return {}
    validate_repo_path(manifest, "disposition manifest")
    manifest_bytes = git(root, "show", f"HEAD:{manifest}")
    raw = json.loads(manifest_bytes.decode("utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("disposition manifest must be a JSON object")
    allowed = {"preserved", "translated", "authorized-retired"}
    dispositions: dict[str, dict[str, Any]] = {}

    # Explicit subtree retirement is intentionally supported only with a manifest
    # that records user authorization and non-empty evidence. Every affected historical
    # path is expanded into an individual disposition in the resulting evidence report.
    subtree_records = raw.get("authorized_subtrees", [])
    if "authorized_subtrees" in raw and not isinstance(subtree_records, list):
        raise ValueError("authorized_subtrees must be a JSON array")
    for entry in subtree_records:
        if not isinstance(entry, dict):
            raise ValueError("each authorized_subtrees entry must be an object")
        subtree = validate_repo_path(entry.get("path", ""), "subtree")
        if not subtree.startswith(scope + "/"):
            raise ValueError(f"authorized subtree must be strictly inside requested scope: {subtree!r}")
        if entry.get("status") != "authorized-retired" or entry.get("user_authorization") is not True:
            raise ValueError(f"subtree retirement for {subtree!r} requires status=authorized-retired and user_authorization=true")
        evidence = entry.get("evidence")
        if not isinstance(evidence, str) or not evidence.strip():
            raise ValueError(f"subtree retirement for {subtree!r} requires non-empty evidence")
        matched = sorted(path for path in historical if path.startswith(subtree + "/"))
        if not matched:
            raise ValueError(f"authorized subtree has no historical paths: {subtree!r}")
        present = sorted(path for path in current if path.startswith(subtree + "/"))
        if present:
            raise ValueError(f"cannot retire subtree containing current tracked paths: {subtree!r}: {present[:5]}")
        for path in matched:
            if path in dispositions:
                raise ValueError(f"overlapping subtree retirement for path {path!r}")
            dispositions[path] = {
                "status": "authorized-retired",
                "evidence": evidence,
                "user_authorization": True,
                "authorization_scope": subtree,
            }

    for path, entry in raw.items():
        if path in {"schema_version", "authorized_subtrees"}:
            continue
        validate_repo_path(path, "disposition path")
        if not (path == scope or path.startswith(scope + "/")):
            raise ValueError(f"disposition path is outside requested scope: {path!r}")
        if path not in historical:
            raise ValueError(f"disposition path is not present in historical Git evidence: {path!r}")
        if path in current:
            raise ValueError(f"disposition is only valid for a missing current path: {path!r}")
        if not isinstance(entry, dict) or entry.get("status") not in allowed:
            raise ValueError(f"invalid disposition for {path!r}; status must be one of {sorted(allowed)}")
        if not isinstance(entry.get("evidence"), str) or not entry["evidence"].strip():
            raise ValueError(f"disposition for {path!r} requires non-empty evidence")
        if entry["status"] in {"preserved", "translated"}:
            target = entry.get("target")
            if not isinstance(target, str) or not target.strip():
                raise ValueError(f"{entry['status']} disposition for {path!r} requires a target path")
            validate_repo_path(target, "target path")
            if target not in current:
                raise ValueError(f"disposition target for {path!r} is not tracked in candidate HEAD: {target!r}")
        if entry["status"] == "authorized-retired" and entry.get("user_authorization") is not True:
            raise ValueError(f"retirement of {path!r} requires user_authorization=true")
        if path in dispositions:
            raise ValueError(f"path has overlapping subtree and individual dispositions: {path!r}")
        dispositions[path] = entry
    return dispositions


def history_events(root: Path, scope: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    raw = git(
        root, "log", "--exclude=refs/stash", "--all", "--full-history", "--find-renames", "--name-status",
        "--format=%H%x09%ct%x09%s", "--", scope,
    ).decode("utf-8", "replace")
    commits: list[dict[str, Any]] = []
    renames: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for line in raw.splitlines():
        if not line:
            continue
        pieces = line.split("\t")
        if len(pieces) >= 3 and len(pieces[0]) in (40, 64) and pieces[0].isalnum() and pieces[1].isdigit():
            current = {"sha": pieces[0], "timestamp": int(pieces[1]), "subject": "\t".join(pieces[2:])}
            commits.append(current)
            continue
        if current is None or len(pieces) < 2:
            continue
        status = pieces[0]
        if status.startswith("R") and len(pieces) >= 3:
            renames.append({
                "commit": current["sha"],
                "similarity": status[1:],
                "previous_path": pieces[1],
                "path": "\t".join(pieces[2:]),
            })
    return commits, renames


def tree_entries(root: Path, commit: str, scope: str) -> list[tuple[str, str]]:
    raw = git(root, "ls-tree", "-r", "-z", "--full-tree", commit, "--", scope)
    entries: list[tuple[str, str]] = []
    for item in raw.split(b"\0"):
        if not item:
            continue
        try:
            metadata, raw_path = item.split(b"\t", 1)
            mode, kind, oid = metadata.decode("ascii").split()
            path = raw_path.decode("utf-8", "surrogateescape")
        except (ValueError, UnicodeDecodeError) as exc:
            raise RuntimeError(f"cannot parse Git tree entry from commit {commit}: {exc}") from exc
        if kind == "blob":
            entries.append((path, oid))
    return entries


def atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        dfd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(dfd)
        finally:
            os.close(dfd)
    finally:
        temporary.unlink(missing_ok=True)


def build_report(root: Path, scope: str, manifest: str | None) -> dict[str, Any]:
    root = root.resolve()
    scope = validate_scope(scope)
    head = git(root, "rev-parse", "--verify", "HEAD").decode("ascii").strip()
    commits_raw = git(root, "log", "--exclude=refs/stash", "--all", "--full-history", "--format=%H", "--", scope)
    commits_in_scope = list(dict.fromkeys(
        line.decode("ascii") for line in commits_raw.splitlines() if line
    ))
    historical: dict[str, set[str]] = {}
    for commit in commits_in_scope:
        for path, oid in tree_entries(root, commit, scope):
            historical.setdefault(path, set()).add(oid)

    current = {path for path, _ in tree_entries(root, head, scope)}
    dispositions = read_dispositions(root, manifest, scope, historical, current)
    manifest_pin = None
    if manifest is not None:
        validate_repo_path(manifest, "disposition manifest")
        manifest_bytes = git(root, "show", f"HEAD:{manifest}")
        manifest_pin = {
            "path": manifest,
            "git_object_id": git(root, "rev-parse", f"HEAD:{manifest}").decode("ascii").strip(),
            "sha256": hashlib.sha256(manifest_bytes).hexdigest(),
            "source": "HEAD Git object",
        }
    commits, renames = history_events(root, scope)
    records: list[dict[str, Any]] = []
    for path in sorted(set(historical) | current):
        present = path in current
        disposition = dispositions.get(path)
        if disposition and disposition["status"] == "authorized-retired":
            status = "authorized-retired"
        elif present:
            status = "present-path"
        elif disposition:
            status = disposition["status"]
        else:
            status = "unresolved-missing"
        records.append({
            "path": path,
            "scope_class": "active",
            "status": status,
            "current": present,
            "historical_object_ids": sorted(historical.get(path, set())),
            "disposition": disposition,
        })

    unresolved = [r for r in records if r["status"] == "unresolved-missing"]
    status = git(root, "status", "--porcelain=v1", "--untracked-files=all").decode("utf-8", "replace").splitlines()
    return {
        "schema_version": 2,
        "scope": scope,
        "head": head,
        "worktree_clean": not status,
        "worktree_status": status,
        "refs": git(root, "for-each-ref", "--format=%(refname):%(objectname)", "refs/heads", "refs/tags", "refs/remotes").decode("utf-8", "replace").splitlines(),
        "dispositions_manifest": manifest_pin,
        "historical_path_count": len(historical),
        "current_path_count": len(current),
        "authorized_retired_count": sum(1 for r in records if r["status"] == "authorized-retired"),
        "commit_count": len(commits),
        "rename_event_count": len(renames),
        "record_count": len(records),
        "unresolved_missing_count": len(unresolved),
        "commits": commits,
        "rename_events": renames,
        "records": records,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Git working tree (default: current directory)")
    parser.add_argument("--scope", default=DEFAULT_SCOPE, help="Repository-relative path scope")
    parser.add_argument("--dispositions", help="JSON file of evidence-backed path dispositions")
    parser.add_argument("--strict", action="store_true", help="fail if active historical paths remain unresolved")
    parser.add_argument("--output", help="write JSON report atomically instead of stdout")
    args = parser.parse_args()
    try:
        report = build_report(Path(args.root), args.scope, args.dispositions)
        encoded = (json.dumps(report, indent=2, sort_keys=True) + "\n").encode("utf-8")
        if args.output:
            atomic_write(Path(args.output), encoded)
        else:
            sys.stdout.buffer.write(encoded)
        if args.strict and report["unresolved_missing_count"]:
            print(
                f"GUP continuity gate: FAIL — {report['unresolved_missing_count']} unresolved active historical paths",
                file=sys.stderr,
            )
            return 1
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, json.JSONDecodeError) as exc:
        print(f"GUP continuity inventory failed closed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

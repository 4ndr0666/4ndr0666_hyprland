#!/usr/bin/env python3
"""Reproducible inventory of historical Hyprland config paths and unresolved losses.

This tool never treats a filename match as proof of semantic equivalence. It inventories
Git objects reachable from local refs and reports missing active-looking paths for review.
Strict mode fails on every missing path without an explicit disposition record.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


DEFAULT_ROOT = "config/hypr"
EXCLUDED_PARTS = {".bak", "legacy-conf-backup", "backup", "backups", "archive"}


def git(root: Path, *args: str) -> bytes:
    return subprocess.run(
        ["git", "-C", str(root), *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout


def active_path(path: str) -> bool:
    parts = Path(path).parts
    return not any(part in EXCLUDED_PARTS for part in parts) and not any(
        part.endswith((".bak", ".backup", "~")) for part in parts
    )


def disposition_map(root: Path, manifest: str | None) -> dict[str, dict[str, Any]]:
    if manifest is None:
        return {}
    raw = json.loads((root / manifest).read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("disposition manifest must be a JSON object keyed by repository path")
    allowed = {"preserved", "translated", "authorized-retired"}
    for path, entry in raw.items():
        if not isinstance(entry, dict) or entry.get("status") not in allowed:
            raise ValueError(f"invalid disposition for {path!r}; status must be one of {sorted(allowed)}")
        if not isinstance(entry.get("evidence"), str) or not entry["evidence"].strip():
            raise ValueError(f"disposition for {path!r} requires non-empty evidence")
        if entry["status"] == "translated" and not entry.get("target"):
            raise ValueError(f"translated disposition for {path!r} requires target")
    return raw


def build_report(root: Path, scope: str, manifest: str | None) -> dict[str, Any]:
    root = root.resolve()
    # rev-list --objects walks Git object history across all refs; duplicate paths are
    # collapsed while object IDs remain available as historical identity evidence.
    objects = git(root, "rev-list", "--objects", "--all", "--", scope).decode("utf-8", "replace")
    historical: dict[str, set[str]] = {}
    for line in objects.splitlines():
        pieces = line.split(" ", 1)
        if len(pieces) == 2 and pieces[1].startswith(scope + "/"):
            historical.setdefault(pieces[1], set()).add(pieces[0])

    current_raw = git(root, "ls-files", "-z", "--", scope)
    current = {p.decode("utf-8", "surrogateescape") for p in current_raw.split(b"\0") if p}
    dispositions = disposition_map(root, manifest)
    records = []
    for path in sorted(set(historical) | current):
        if not active_path(path):
            continue
        present = path in current
        if present:
            status = "present-path"
        elif path in dispositions:
            status = dispositions[path]["status"]
        else:
            status = "unresolved-missing"
        records.append({
            "path": path,
            "status": status,
            "current": present,
            "historical_object_ids": sorted(historical.get(path, set())),
            "disposition": dispositions.get(path),
        })
    unresolved = [r for r in records if r["status"] == "unresolved-missing"]
    return {
        "schema_version": 1,
        "scope": scope,
        "head": git(root, "rev-parse", "HEAD").decode().strip(),
        "refs": git(root, "for-each-ref", "--format=%(refname):%(objectname)").decode().splitlines(),
        "historical_path_count": len(historical),
        "current_path_count": len(current),
        "record_count": len(records),
        "unresolved_missing_count": len(unresolved),
        "records": records,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Git working tree (default: current directory)")
    parser.add_argument("--scope", default=DEFAULT_ROOT, help="Repository-relative path scope")
    parser.add_argument("--dispositions", help="JSON file of evidence-backed path dispositions")
    parser.add_argument("--strict", action="store_true", help="fail if any in-scope historical path is unresolved")
    parser.add_argument("--output", help="write JSON report to this path instead of stdout")
    args = parser.parse_args()
    try:
        root = Path(args.root)
        report = build_report(root, args.scope.rstrip("/"), args.dispositions)
        encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
        if args.output:
            target = Path(args.output)
            target.parent.mkdir(parents=True, exist_ok=True)
            temporary = target.with_name(target.name + ".tmp")
            try:
                temporary.write_text(encoded, encoding="utf-8")
                temporary.replace(target)
            except BaseException:
                temporary.unlink(missing_ok=True)
                raise
        else:
            sys.stdout.write(encoded)
        if args.strict and report["unresolved_missing_count"]:
            print(
                f"GUP continuity gate: {report['unresolved_missing_count']} unresolved historical paths",
                file=sys.stderr,
            )
            return 1
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"GUP continuity inventory failed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

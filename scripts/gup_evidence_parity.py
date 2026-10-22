#!/usr/bin/env python3
"""Fail closed when the independent GUP continuity reports disagree."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


class EvidenceMismatch(ValueError):
    """Raised when independent GUP reports do not describe the same history."""


def load_report(path: Path) -> dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as stream:
            value = json.load(stream)
    except (OSError, json.JSONDecodeError) as exc:
        raise EvidenceMismatch(f"cannot read evidence report {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise EvidenceMismatch(f"evidence report must be a JSON object: {path}")
    return value


def unique_path_records(report: dict[str, Any], key: str, path_key: str) -> dict[str, dict[str, Any]]:
    rows = report.get(key)
    if not isinstance(rows, list):
        raise EvidenceMismatch(f"{key} must be an array")
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get(path_key), str):
            raise EvidenceMismatch(f"malformed path record in {key}: {row!r}")
        path = row[path_key]
        if path in result:
            raise EvidenceMismatch(f"duplicate path record in {key}: {path!r}")
        result[path] = row
    return result


def rename_keys(report: dict[str, Any]) -> list[tuple[str, str, str, str]]:
    rows = report.get("rename_events")
    if not isinstance(rows, list):
        raise EvidenceMismatch("rename_events must be an array")
    result = []
    for row in rows:
        if not isinstance(row, dict):
            raise EvidenceMismatch(f"malformed rename event: {row!r}")
        similarity = row.get("similarity")
        if similarity is None and isinstance(row.get("status"), str) and row["status"].startswith("R"):
            similarity = row["status"][1:]
        fields = (row.get("commit"), row.get("previous_path"), row.get("path"), similarity)
        if not all(isinstance(value, str) for value in fields):
            raise EvidenceMismatch(f"rename event lacks commit/path/similarity fields: {row!r}")
        result.append(fields)
    return sorted(result)


def compare(continuity: dict[str, Any], rehydration: dict[str, Any]) -> dict[str, int]:
    for key in ("head", "scope", "historical_path_count", "current_path_count",
                "authorized_retired_count", "unresolved_missing_count"):
        if continuity.get(key) != rehydration.get(key):
            raise EvidenceMismatch(
                f"report mismatch for {key}: continuity={continuity.get(key)!r}, "
                f"rehydration={rehydration.get(key)!r}"
            )

    left = unique_path_records(continuity, "records", "path")
    right = unique_path_records(rehydration, "path_records", "path")
    if left.keys() != right.keys():
        missing = sorted(left.keys() - right.keys())
        extra = sorted(right.keys() - left.keys())
        raise EvidenceMismatch(f"path inventory mismatch: missing_from_rehydration={missing[:10]!r}, extra_in_rehydration={extra[:10]!r}")

    for path in sorted(left):
        a, b = left[path], right[path]
        if a.get("status") != b.get("status"):
            raise EvidenceMismatch(f"path status mismatch for {path!r}: {a.get('status')!r} != {b.get('status')!r}")
        if a.get("current") != b.get("present_at_head"):
            raise EvidenceMismatch(f"HEAD presence mismatch for {path!r}")
        historical_a = sorted(set(a.get("historical_object_ids", [])))
        historical_b = sorted(set(b.get("historical_blob_ids", [])))
        if historical_a != historical_b:
            raise EvidenceMismatch(f"historical blob set mismatch for {path!r}")
        if a.get("disposition") != b.get("disposition"):
            raise EvidenceMismatch(f"disposition mismatch for {path!r}")

    left_renames = rename_keys(continuity)
    right_renames = rename_keys(rehydration)
    if left_renames != right_renames:
        left_set, right_set = set(left_renames), set(right_renames)
        raise EvidenceMismatch(
            f"rename evidence mismatch: missing_from_rehydration={sorted(left_set-right_set)[:10]!r}, "
            f"extra_in_rehydration={sorted(right_set-left_set)[:10]!r}"
        )

    return {"paths_compared": len(left), "rename_events_compared": len(left_renames)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--continuity", required=True, type=Path)
    parser.add_argument("--rehydration", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = compare(load_report(args.continuity), load_report(args.rehydration))
        print(
            "GUP evidence parity: PASS — "
            f"paths={result['paths_compared']}, rename_events={result['rename_events_compared']}"
        )
        return 0
    except (EvidenceMismatch, TypeError) as exc:
        print(f"GUP evidence parity: FAIL — {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

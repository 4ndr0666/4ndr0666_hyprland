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
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise EvidenceMismatch(f"cannot read evidence report {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise EvidenceMismatch(f"evidence report must be a JSON object: {path}")
    return value


def require_count(report: dict[str, Any], key: str) -> int:
    value = report.get(key)
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise EvidenceMismatch(f"{key} must be a non-negative integer")
    return value


def unique_path_records(report: dict[str, Any], key: str, path_key: str) -> dict[str, dict[str, Any]]:
    rows = report.get(key)
    if not isinstance(rows, list):
        raise EvidenceMismatch(f"{key} must be an array")
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get(path_key), str) or not row[path_key]:
            raise EvidenceMismatch(f"malformed path record in {key}: {row!r}")
        path = row[path_key]
        if path in result:
            raise EvidenceMismatch(f"duplicate path record in {key}: {path!r}")
        result[path] = row
    return result


def validate_report(report: dict[str, Any], records_key: str, path_key: str, current_key: str,
                    blobs_key: str) -> dict[str, dict[str, Any]]:
    for key in ("head", "scope"):
        if not isinstance(report.get(key), str) or not report[key]:
            raise EvidenceMismatch(f"{key} must be a non-empty string")

    records = unique_path_records(report, records_key, path_key)
    historical_count = 0
    current_count = 0
    retired_count = 0
    unresolved_count = 0
    allowed_statuses = {"present-path", "unresolved-missing", "authorized-retired", "translated", "preserved"}

    for path, row in records.items():
        status = row.get("status")
        if status not in allowed_statuses:
            raise EvidenceMismatch(f"invalid status for {path!r}: {status!r}")
        present = row.get(current_key)
        if not isinstance(present, bool):
            raise EvidenceMismatch(f"{current_key} must be boolean for {path!r}")
        blobs = row.get(blobs_key)
        if not isinstance(blobs, list) or any(not isinstance(oid, str) or not oid for oid in blobs):
            raise EvidenceMismatch(f"{blobs_key} must be an array of non-empty strings for {path!r}")
        if len(blobs) != len(set(blobs)):
            raise EvidenceMismatch(f"duplicate historical blob ID for {path!r}")
        if blobs:
            historical_count += 1
        disposition = row.get("disposition")
        if disposition is not None and not isinstance(disposition, dict):
            raise EvidenceMismatch(f"disposition must be an object or null for {path!r}")

        if status == "present-path":
            if not present or disposition is not None:
                raise EvidenceMismatch(f"present-path status contradicts HEAD/disposition for {path!r}")
        elif status == "unresolved-missing":
            unresolved_count += 1
            if present or disposition is not None:
                raise EvidenceMismatch(f"unresolved-missing status contradicts HEAD/disposition for {path!r}")
        else:
            if present or not isinstance(disposition, dict) or disposition.get("status") != status:
                raise EvidenceMismatch(f"{status} status contradicts HEAD/disposition for {path!r}")
        if present:
            current_count += 1
        if status == "authorized-retired":
            retired_count += 1

    expected = {
        "historical_path_count": historical_count,
        "current_path_count": current_count,
        "authorized_retired_count": retired_count,
        "unresolved_missing_count": unresolved_count,
    }
    for key, actual in expected.items():
        if require_count(report, key) != actual:
            raise EvidenceMismatch(f"{key} disagrees with path records: report={report[key]!r}, records={actual}")
    if "record_count" in report and require_count(report, "record_count") != len(records):
        raise EvidenceMismatch("record_count disagrees with path records")

    renames = report.get("rename_events")
    if not isinstance(renames, list):
        raise EvidenceMismatch("rename_events must be an array")
    if "rename_event_count" in report and require_count(report, "rename_event_count") != len(renames):
        raise EvidenceMismatch("rename_event_count disagrees with rename_events")
    return records


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
        if not all(isinstance(value, str) and value for value in fields):
            raise EvidenceMismatch(f"rename event lacks commit/path/similarity fields: {row!r}")
        result.append(fields)
    if len(result) != len(set(result)):
        raise EvidenceMismatch("duplicate normalized rename event")
    return sorted(result)


def compare(continuity: dict[str, Any], rehydration: dict[str, Any]) -> dict[str, int]:
    left = validate_report(continuity, "records", "path", "current", "historical_object_ids")
    right = validate_report(rehydration, "path_records", "path", "present_at_head", "historical_blob_ids")

    for key in ("head", "scope", "historical_path_count", "current_path_count",
                "authorized_retired_count", "unresolved_missing_count"):
        if continuity.get(key) != rehydration.get(key):
            raise EvidenceMismatch(
                f"report mismatch for {key}: continuity={continuity.get(key)!r}, "
                f"rehydration={rehydration.get(key)!r}"
            )

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
        historical_a = sorted(a["historical_object_ids"])
        historical_b = sorted(b["historical_blob_ids"])
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

    continuity_manifest = continuity.get("dispositions_manifest")
    rehydration_manifest = rehydration.get("dispositions_manifest")
    if continuity_manifest is not None and rehydration_manifest is not None:
        if continuity_manifest != rehydration_manifest:
            raise EvidenceMismatch("disposition manifest pins differ between reports")

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

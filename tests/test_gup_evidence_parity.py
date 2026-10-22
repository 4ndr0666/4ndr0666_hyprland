from __future__ import annotations

import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/gup_evidence_parity.py"


def reports():
    path = {
        "path": "config/hypr/old.conf",
        "status": "translated",
        "current": False,
        "historical_object_ids": ["blob-a", "blob-b"],
        "disposition": {"status": "translated", "target": "config/hypr/new.lua", "evidence": "reviewed"},
    }
    rehydration_path = {
        "path": path["path"],
        "status": path["status"],
        "present_at_head": path["current"],
        "historical_blob_ids": list(path["historical_object_ids"]),
        "disposition": copy.deepcopy(path["disposition"]),
    }
    rename = {"commit": "commit-1", "similarity": "100", "previous_path": "config/hypr/a.conf", "path": "config/hypr/b.conf"}
    rename_rehydration = {**rename, "parent": "commit-0", "status": "R100"}
    common = {
        "head": "head-1", "scope": "config/hypr", "historical_path_count": 1,
        "current_path_count": 0, "authorized_retired_count": 0,
        "unresolved_missing_count": 0, "rename_events": [rename], "rename_event_count": 1,
    }
    a = {**common, "records": [path], "record_count": 1}
    b = {**common, "path_records": [rehydration_path]}
    b["rename_events"] = [rename_rehydration]
    return a, b


def load_module():
    spec = importlib.util.spec_from_file_location("gup_evidence_parity", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class EvidenceParityTests(unittest.TestCase):
    def test_equivalent_reports_pass_despite_schema_specific_fields(self):
        module = load_module()
        result = module.compare(*reports())
        self.assertEqual(result, {"paths_compared": 1, "rename_events_compared": 1})

    def test_head_mismatch_fails(self):
        module = load_module()
        a, b = reports()
        b["head"] = "other-head"
        with self.assertRaises(module.EvidenceMismatch):
            module.compare(a, b)

    def test_historical_blob_mismatch_fails(self):
        module = load_module()
        a, b = reports()
        b["path_records"][0]["historical_blob_ids"] = ["different-blob"]
        with self.assertRaises(module.EvidenceMismatch):
            module.compare(a, b)

    def test_rename_mismatch_fails(self):
        module = load_module()
        a, b = reports()
        b["rename_events"][0]["path"] = "config/hypr/wrong.conf"
        with self.assertRaises(module.EvidenceMismatch):
            module.compare(a, b)

    def test_inconsistent_internal_path_counts_fail(self):
        module = load_module()
        a, b = reports()
        a["historical_path_count"] = 2
        with self.assertRaisesRegex(module.EvidenceMismatch, "historical_path_count disagrees"):
            module.compare(a, b)

    def test_boolean_is_not_accepted_as_integer_count(self):
        module = load_module()
        a, b = reports()
        a["current_path_count"] = False
        with self.assertRaisesRegex(module.EvidenceMismatch, "non-negative integer"):
            module.compare(a, b)

    def test_duplicate_normalized_rename_event_fails(self):
        module = load_module()
        a, b = reports()
        a["rename_events"].append(copy.deepcopy(a["rename_events"][0]))
        a["rename_event_count"] = 2
        with self.assertRaisesRegex(module.EvidenceMismatch, "duplicate normalized rename"):
            module.compare(a, b)

    def test_duplicate_path_record_fails(self):
        module = load_module()
        a, b = reports()
        a["records"].append(copy.deepcopy(a["records"][0]))
        a["record_count"] = 2
        with self.assertRaisesRegex(module.EvidenceMismatch, "duplicate path record"):
            module.compare(a, b)

    def test_disposition_manifest_pin_mismatch_fails(self):
        module = load_module()
        a, b = reports()
        a["dispositions_manifest"] = {"git_object_id": "one", "sha256": "a"}
        b["dispositions_manifest"] = {"git_object_id": "two", "sha256": "b"}
        with self.assertRaisesRegex(module.EvidenceMismatch, "manifest pins differ"):
            module.compare(a, b)

    def test_cli_reports_failure_for_malformed_report(self):
        with tempfile.TemporaryDirectory() as temp:
            a = Path(temp) / "continuity.json"
            b = Path(temp) / "rehydration.json"
            a.write_text(json.dumps(reports()[0]), encoding="utf-8")
            b.write_text("not-json", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--continuity", str(a), "--rehydration", str(b)],
                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=10,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("GUP evidence parity: FAIL", result.stderr)

    def test_cli_reports_failure_for_invalid_utf8(self):
        with tempfile.TemporaryDirectory() as temp:
            a = Path(temp) / "continuity.json"
            b = Path(temp) / "rehydration.json"
            a.write_text(json.dumps(reports()[0]), encoding="utf-8")
            b.write_bytes(b"\xff")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--continuity", str(a), "--rehydration", str(b)],
                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=10,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("GUP evidence parity: FAIL", result.stderr)
            self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)

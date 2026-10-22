from __future__ import annotations

import copy
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
        "unresolved_missing_count": 0, "rename_events": [rename],
    }
    a = {**common, "records": [path]}
    b = {**common, "path_records": [rehydration_path], "rename_events": [rename_rehydration]}
    return a, b


class EvidenceParityTests(unittest.TestCase):
    def test_equivalent_reports_pass_despite_schema_specific_fields(self):
        from importlib.util import spec_from_file_location, module_from_spec
        spec = spec_from_file_location("gup_evidence_parity", SCRIPT)
        module = module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(module)
        result = module.compare(*reports())
        self.assertEqual(result, {"paths_compared": 1, "rename_events_compared": 1})

    def test_head_mismatch_fails(self):
        from importlib.util import spec_from_file_location, module_from_spec
        spec = spec_from_file_location("gup_evidence_parity", SCRIPT)
        module = module_from_spec(spec); assert spec.loader is not None; spec.loader.exec_module(module)
        a, b = reports(); b["head"] = "other-head"
        with self.assertRaises(module.EvidenceMismatch): module.compare(a, b)

    def test_historical_blob_mismatch_fails(self):
        from importlib.util import spec_from_file_location, module_from_spec
        spec = importlib.util.spec_from_file_location("gup_evidence_parity", SCRIPT)
        module = importlib.util.module_from_spec(spec); assert spec.loader is not None; spec.loader.exec_module(module)
        a, b = reports(); b["path_records"][0]["historical_blob_ids"] = ["different-blob"]
        with self.assertRaises(module.EvidenceMismatch): module.compare(a, b)

    def test_rename_mismatch_fails(self):
        from importlib.util import spec_from_file_location, module_from_spec
        spec = importlib.util.spec_from_file_location("gup_evidence_parity", SCRIPT)
        module = importlib.util.module_from_spec(spec); assert spec.loader is not None; spec.loader.exec_module(module)
        a, b = reports(); b["rename_events"][0]["path"] = "config/hypr/wrong.conf"
        with self.assertRaises(module.EvidenceMismatch): module.compare(a, b)

    def test_cli_reports_failure_for_malformed_report(self):
        with tempfile.TemporaryDirectory() as temp:
            a = Path(temp) / "continuity.json"; b = Path(temp) / "rehydration.json"
            a.write_text(json.dumps(reports()[0]), encoding="utf-8")
            b.write_text("not-json", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--continuity", str(a), "--rehydration", str(b)],
                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=10,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("GUP evidence parity: FAIL", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)

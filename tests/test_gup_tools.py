from __future__ import annotations
import hashlib, json, os, subprocess, sys, tempfile, unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PYTHON=sys.executable

def run(*args, cwd=None, check=False):
    return subprocess.run(args,cwd=cwd,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=check,timeout=60)

def init_repo(path:Path):
    run("git","init","-q",str(path),check=True)
    run("git","-C",str(path),"config","user.name","GUP Test",check=True)
    run("git","-C",str(path),"config","user.email","gup-test@example.invalid",check=True)

def commit(path:Path,message:str):
    run("git","-C",str(path),"add","-A",check=True)
    run("git","-C",str(path),"commit","-qm",message,check=True)
    return run("git","-C",str(path),"rev-parse","HEAD",check=True).stdout.strip()

class GUPToolTests(unittest.TestCase):
    def test_init_is_idempotent_and_does_not_overwrite(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)/"project"; root.mkdir()
            first=run(PYTHON,str(ROOT/"scripts/gup_init.py"),"--root",str(root))
            self.assertEqual(first.returncode,0,first.stderr)
            metadata=root/".gup/project.json"; original=metadata.read_bytes()
            self.assertEqual(json.loads(original)["state"],"BLOCKED_BASELINE_NOT_ESTABLISHED")
            second=run(PYTHON,str(ROOT/"scripts/gup_init.py"),"--root",str(root))
            self.assertEqual(second.returncode,0,second.stderr)
            self.assertEqual(metadata.read_bytes(),original)
            self.assertTrue((root/".git").is_dir())

    def test_init_rejects_accidental_nested_repository(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td)/"outer"; root.mkdir(); init_repo(root); (root/"tracked.txt").write_text("x\n"); commit(root,"root")
            nested=root/"nested"; nested.mkdir()
            result=run(PYTHON,str(ROOT/"scripts/gup_init.py"),"--root",str(nested))
            self.assertEqual(result.returncode,2)
            self.assertFalse((nested/".git").exists())
            self.assertFalse((nested/".gup").exists())

    def test_inventory_records_hashes_and_rejects_dirty_worktree(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td); init_repo(root); f=root/"unit.txt"; f.write_text("baseline\n"); commit(root,"baseline")
            clean=run(PYTHON,str(ROOT/"scripts/gup_inventory.py"),"--root",str(root))
            self.assertEqual(clean.returncode,0,clean.stderr)
            data=json.loads(clean.stdout); self.assertTrue(data["worktree_clean"])
            self.assertEqual(data["files"][0]["sha256"],hashlib.sha256(b"baseline\n").hexdigest())
            f.write_text("dirty\n")
            dirty=run(PYTHON,str(ROOT/"scripts/gup_inventory.py"),"--root",str(root))
            self.assertEqual(dirty.returncode,1)

    def test_alignment_is_bidirectional(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/"alignment.json"
            edge={"id":"api-client","provider":"src/provider.py:serve","consumer":"src/client.py:call"}
            doc={"declarations":[{**edge,"declaration_evidence":"docs/contracts.md#api","provider_evidence":"src/provider.py:serve","consumer_evidence":"src/client.py:call"}],"observations":[{**edge,"observation_evidence":"integration test test_api.py::test_roundtrip"}]}
            p.write_text(json.dumps(doc)); good=run(PYTHON,str(ROOT/"scripts/gup_alignment.py"),str(p))
            self.assertEqual(good.returncode,0,good.stdout+good.stderr)
            doc["observations"]=[]; p.write_text(json.dumps(doc)); bad=run(PYTHON,str(ROOT/"scripts/gup_alignment.py"),str(p))
            self.assertEqual(bad.returncode,1); self.assertIn("FAIL",bad.stdout)

    def test_history_inventory_flags_removed_paths_and_strict_fails(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td); init_repo(root); (root/"config/archive").mkdir(parents=True)
            (root/"config/legacy.conf").write_text("old\n"); (root/"config/archive/backup.conf").write_text("archived-looking but still historical\n"); commit(root,"old config")
            (root/"config/legacy.conf").unlink(); (root/"config/archive/backup.conf").unlink()
            (root/"config/current.lua").write_text("new\n"); commit(root,"migrate config")
            report=run(PYTHON,str(ROOT/"scripts/gup_history_continuity.py"),"--root",str(root))
            self.assertEqual(report.returncode,0,report.stderr)
            data=json.loads(report.stdout); paths={x["path"]:x for x in data["records"]}
            self.assertEqual(paths["config/legacy.conf"]["status"],"unresolved-missing")
            self.assertIn("config/archive/backup.conf",paths,"archive-named historical path must not be excluded")
            self.assertEqual(paths["config/archive/backup.conf"]["status"],"unresolved-missing")
            strict=run(PYTHON,str(ROOT/"scripts/gup_history_continuity.py"),"--root",str(root),"--strict")
            self.assertEqual(strict.returncode,1)

    def test_validator_passes_only_complete_committed_evidence(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td); init_repo(root); unit=root/"unit.txt"; unit.write_text("one\n"); baseline=commit(root,"baseline")
            unit.write_text("two\n"); candidate=commit(root,"candidate")
            bdata={"commit":baseline,"units":[{"id":"unit.txt","sha256":hashlib.sha256(b"one\n").hexdigest()}]}
            cdata={"commit":candidate,"units":[{"id":"unit.txt","sha256":hashlib.sha256(b"two\n").hexdigest()}]}
            b=root.parent/(root.name+"-baseline.json"); c=root.parent/(root.name+"-candidate.json"); e=root.parent/(root.name+"-evidence.json")
            b.write_text(json.dumps(bdata)); c.write_text(json.dumps(cdata))
            surfaces=["entry_points","loaders","callers","providers","consumers","configuration_paths","install_migration_paths","tests","runtime_dependencies"]
            evidence={"protocol_version":"7.0.0","baseline_commit":baseline,"candidate_commit":candidate,
              "units":{"baseline_manifest":str(b),"candidate_manifest":str(c),"comparison_artifact":"sha256:comparison-proof"},
              "comparison":[{"unit_id":"unit.txt","classification":"CHANGED"}],
              "semantic_reviews":[{"unit_id":"unit.txt","classification":"CHANGED","verdict":"PRESERVED_SUPERSET","rationale":"All baseline behavior is preserved and new behavior is additive.","evidence":"review:unit.txt"}],
              "alignment":{"status":"PASS","evidence":"alignment report sha256:alignment"},
              "architecture_gate":{"status":"PASS","evidence":"architecture review sha256:architecture"},
              "integration_closure":[{"surface":s,"status":"CLOSED","evidence":"reviewed integration graph for "+s} for s in surfaces],
              "manifest_targets":[],"tests":[{"command":"python -m unittest","exit_code":0,"evidence":"CI run 123 passed"}]}
            e.write_text(json.dumps(evidence)); result=run(PYTHON,str(ROOT/"scripts/gup_validate.py"),"--root",str(root),"--evidence",str(e))
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertEqual(json.loads(result.stdout)["status"],"PASS")
            unit.write_text("uncommitted\n")
            dirty=run(PYTHON,str(ROOT/"scripts/gup_validate.py"),"--root",str(root),"--evidence",str(e))
            self.assertEqual(dirty.returncode,1); self.assertIn("dirty",dirty.stdout)
            b.unlink(missing_ok=True); c.unlink(missing_ok=True); e.unlink(missing_ok=True)

if __name__=="__main__": unittest.main(verbosity=2)

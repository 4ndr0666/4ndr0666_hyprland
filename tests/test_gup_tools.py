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
    def test_atomizer_tracks_quoted_substitution_body_changes(self):
        helper=ROOT/"config/hypr/scripts/RainbowBordersToggle.sh"
        self.assertEqual(run("bash","-n",str(helper)).returncode,0)
        baseline=run(PYTHON,str(ROOT/"golden_unit_hash.py"),"--baseline",str(helper),"--manifest-only")
        self.assertEqual(baseline.returncode,0,baseline.stderr)
        self.assertNotIn("warning",baseline.stderr)
        units={row["unit"]:row for row in json.loads(baseline.stdout)["manifest"]}
        self.assertEqual(set(units),{"fail","refresh_borders","disable_borders","enable_borders","set_mode"})
        with tempfile.TemporaryDirectory() as td:
            candidate=Path(td)/"RainbowBordersToggle.sh"
            original=helper.read_text()
            changed=original.replace("RainbowBorders.sh has no readable EFFECT_TYPE assignment.","RainbowBorders.sh has no valid EFFECT_TYPE assignment.")
            self.assertNotEqual(changed,original)
            candidate.write_text(changed)
            result=run(PYTHON,str(ROOT/"golden_unit_hash.py"),"--baseline",str(helper),"--candidate",str(candidate))
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertNotIn("warning",result.stderr)
            differences={row["unit"]:row["verdict"] for row in json.loads(result.stdout)["diff"]}
            self.assertEqual(differences["set_mode"],"CHANGED")
            self.assertTrue(all(verdict=="UNCHANGED" for name,verdict in differences.items() if name!="set_mode"))

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

    def test_history_inventory_excludes_suk_backup_refs_but_includes_remote_refs(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td); init_repo(root); folder=root/"config/hypr"; folder.mkdir(parents=True)
            (folder/"current.lua").write_text("return true\n"); main_commit=commit(root,"main source history")
            main_branch=run("git","-C",str(root),"branch","--show-current",check=True).stdout.strip()

            run("git","-C",str(root),"checkout","-b","accepted-side",check=True)
            (folder/"side-only.conf").write_text("accepted remote branch history\n")
            side_commit=commit(root,"accepted remote branch history")
            run("git","-C",str(root),"checkout",main_branch,check=True)
            run("git","-C",str(root),"branch","-D","accepted-side",check=True)
            run("git","-C",str(root),"update-ref","refs/remotes/origin/accepted-side",side_commit,check=True)

            run("git","-C",str(root),"checkout","-b","suk-wip-fixture",check=True)
            (folder/"wip-only.conf").write_text("operational backup only\n")
            wip_commit=commit(root,"SUK operational WIP backup")
            run("git","-C",str(root),"checkout",main_branch,check=True)
            run("git","-C",str(root),"branch","-D","suk-wip-fixture",check=True)
            run("git","-C",str(root),"update-ref","refs/suk/wip-backups/test",wip_commit,check=True)

            result=run(PYTHON,str(ROOT/"scripts/gup-history-continuity.py"),"--root",str(root))
            self.assertEqual(result.returncode,0,result.stderr)
            data=json.loads(result.stdout); paths={row["path"]:row for row in data["records"]}
            commits={row["sha"] for row in data["commits"]}
            self.assertIn(main_commit,commits); self.assertIn(side_commit,commits)
            self.assertNotIn(wip_commit,commits)
            self.assertIn("config/hypr/side-only.conf",paths)
            self.assertNotIn("config/hypr/wip-only.conf",paths)
            accepted_refs={ref.split(":",1)[0] for ref in data["refs"]}
            self.assertIn("refs/remotes/origin/accepted-side",accepted_refs)
            excluded={row["ref"]:row["reason"] for row in data["excluded_refs"]}
            self.assertIn("refs/suk/wip-backups/test",excluded)
            self.assertIn("SUK operational",excluded["refs/suk/wip-backups/test"])

            # The older GUP v7 toolchain entry point must obey the same ref policy.
            legacy=run(PYTHON,str(ROOT/"scripts/gup_history_continuity.py"),"--root",str(root))
            self.assertEqual(legacy.returncode,0,legacy.stderr)
            legacy_data=json.loads(legacy.stdout)
            legacy_paths={row["path"]:row for row in legacy_data["records"]}
            legacy_commits={row["sha"] for row in legacy_data["commits"]}
            self.assertIn(main_commit,legacy_commits); self.assertIn(side_commit,legacy_commits)
            self.assertNotIn(wip_commit,legacy_commits)
            self.assertIn("config/hypr/side-only.conf",legacy_paths)
            self.assertNotIn("config/hypr/wip-only.conf",legacy_paths)
            self.assertIn("refs/suk/wip-backups/test",{row["ref"] for row in legacy_data["excluded_refs"]})

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

from __future__ import annotations
import hashlib, json, subprocess, sys, tempfile, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; PYTHON=sys.executable

def git(root:Path,*args:str)->str:
    p=subprocess.run(["git","-C",str(root),*args],text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=False,timeout=60)
    if p.returncode: raise AssertionError(p.stderr)
    return p.stdout.strip()
def commit(root:Path,message:str)->str:
    git(root,"add","-A"); git(root,"commit","-m",message); return git(root,"rev-parse","HEAD")

class RehydrationVerificationTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.root=Path(self.temp.name)
        git(self.root,"init","-q"); git(self.root,"config","user.name","GUP Test"); git(self.root,"config","user.email","gup-test@example.invalid")
    def tearDown(self): self.temp.cleanup()
    def invoke(self,*args):
        return subprocess.run([PYTHON,str(ROOT/"scripts/gup_rehydration_verify.py"),"--root",str(self.root),"--scope","config/hypr",*args],text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=False,timeout=60)
    def test_recomputes_historical_git_and_sha256_pins(self):
        folder=self.root/"config/hypr"; folder.mkdir(parents=True); old=folder/"old.conf"; old.write_bytes(b"legacy\n\x00bytes\n")
        first=commit(self.root,"historical configuration"); old.unlink(); (folder/"new.lua").write_bytes(b"return true\n"); second=commit(self.root,"translated configuration")
        result=self.invoke(); self.assertEqual(result.returncode,0,result.stderr); report=json.loads(result.stdout)
        self.assertIn(first,{x["commit"] for x in report["commits"]}); self.assertIn(second,{x["commit"] for x in report["commits"]})
        first_commit=next(x for x in report["commits"] if x["commit"]==first)
        self.assertEqual(report["object_pins"][first]["git_object_type"],"commit")
        self.assertEqual(report["object_pins"][first_commit["tree_object_id"]]["git_object_type"],"tree")
        self.assertTrue(report["verification"]["all_git_object_ids_recomputed"])
        record=next(x for x in report["path_records"] if x["path"]=="config/hypr/old.conf"); self.assertEqual(record["status"],"unresolved-missing")
        pin=report["blob_pins"][record["historical_blob_ids"][0]]
        self.assertEqual(pin["sha256"],hashlib.sha256(b"legacy\n\x00bytes\n").hexdigest()); self.assertEqual(pin["git_object_id"],pin["git_object_id_recomputed"])
        self.assertEqual(record["versions"][0]["git_show_spec"],f"{first}:config/hypr/old.conf")
        repeat=self.invoke(); self.assertEqual(repeat.returncode,0,repeat.stderr); self.assertEqual(repeat.stdout,result.stdout)
    def test_strict_fails_for_unresolved_historical_path(self):
        folder=self.root/"config/hypr"; folder.mkdir(parents=True); (folder/"old.conf").write_text("old\n"); commit(self.root,"old")
        (folder/"old.conf").unlink(); (folder/"new.lua").write_text("new\n"); commit(self.root,"new")
        result=self.invoke("--strict"); self.assertEqual(result.returncode,1,result.stderr); self.assertIn("unresolved paths=1",result.stderr)
    def test_translated_disposition_requires_existing_current_target(self):
        folder=self.root/"config/hypr"; folder.mkdir(parents=True); (folder/"old.conf").write_text("old\n"); commit(self.root,"old")
        (folder/"old.conf").unlink(); (folder/"new.lua").write_text("new\n"); commit(self.root,"new")
        (self.root/"dispositions.json").write_text(json.dumps({"config/hypr/old.conf":{"status":"translated","target":"config/hypr/new.lua","evidence":"reviewed migration and behavioral test"}}))
        commit(self.root,"commit disposition manifest")
        result=self.invoke("--dispositions","dispositions.json","--strict"); self.assertEqual(result.returncode,0,result.stderr)
        record=next(x for x in json.loads(result.stdout)["path_records"] if x["path"]=="config/hypr/old.conf"); self.assertEqual(record["status"],"translated")
    def test_missing_translation_target_fails_closed(self):
        folder=self.root/"config/hypr"; folder.mkdir(parents=True); (folder/"old.conf").write_text("old\n"); commit(self.root,"old")
        (folder/"old.conf").unlink(); (folder/"new.lua").write_text("new\n"); commit(self.root,"new")
        (self.root/"dispositions.json").write_text(json.dumps({"config/hypr/old.conf":{"status":"translated","target":"config/hypr/missing.lua","evidence":"reviewed migration"}}))
        commit(self.root,"commit disposition manifest")
        result=self.invoke("--dispositions","dispositions.json"); self.assertEqual(result.returncode,2); self.assertIn("translated target is not current",result.stderr)
    def test_archive_name_does_not_authorize_retirement(self):
        folder=self.root/"config/hypr/archive"; folder.mkdir(parents=True)
        old=folder/"old.conf"; old.write_text("previously active configuration\n"); commit(self.root,"historical configuration under archive-named path")
        old.unlink(); (self.root/"config/hypr/current.lua").write_text("return true\n"); commit(self.root,"remove historical path")
        result=self.invoke("--strict"); self.assertEqual(result.returncode,1,result.stderr)
        record=next(x for x in json.loads(result.stdout)["path_records"] if x["path"]=="config/hypr/archive/old.conf")
        self.assertEqual(record["scope_class"],"active"); self.assertEqual(record["status"],"unresolved-missing")
        self.assertEqual(json.loads(result.stdout)["unresolved_missing_count"],1)
    def test_missing_historical_blob_fails_closed(self):
        folder=self.root/"config/hypr"; folder.mkdir(parents=True)
        old=folder/"old.conf"; old.write_text("old blob\n"); commit(self.root,"historical blob")
        oid=git(self.root,"rev-parse","HEAD:config/hypr/old.conf")
        object_path=self.root/".git"/"objects"/oid[:2]/oid[2:]
        self.assertTrue(object_path.is_file(),f"expected loose test object at {object_path}")
        object_path.unlink()
        result=self.invoke()
        self.assertEqual(result.returncode,2,result.stderr)
    def test_authorized_subtree_disposes_existing_historical_paths(self):
        folder=self.root/"config/hypr/legacy"; folder.mkdir(parents=True)
        old=folder/"old.conf"; old.write_text("legacy behavior\\n"); commit(self.root,"historical legacy configuration")
        old.unlink(); (self.root/"config/hypr/current.lua").write_text("return true\\n"); commit(self.root,"remove retired subtree")
        manifest={"authorized_subtrees":[{"path":"config/hypr/legacy","status":"authorized-retired","evidence":"explicit synthetic test authorization","user_authorization":True}]}
        (self.root/"dispositions.json").write_text(json.dumps(manifest)); commit(self.root,"commit valid subtree disposition")
        result=self.invoke("--dispositions","dispositions.json","--strict")
        self.assertEqual(result.returncode,0,result.stderr)
        report=json.loads(result.stdout)
        record=next(x for x in report["path_records"] if x["path"]=="config/hypr/legacy/old.conf")
        self.assertEqual(record["status"],"authorized-retired")
        self.assertEqual(record["disposition"]["authorization_scope"],"config/hypr/legacy")
        self.assertEqual(report["unresolved_missing_count"],0)

    def test_empty_authorized_subtree_fails_closed(self):
        folder=self.root/"config/hypr"; folder.mkdir(parents=True)
        (folder/"current.lua").write_text("return true\n"); commit(self.root,"current configuration")
        manifest={"authorized_subtrees":[{"path":"config/hypr/does-not-exist","status":"authorized-retired","evidence":"no historical paths should be silently accepted","user_authorization":True}]}
        (self.root/"dispositions.json").write_text(json.dumps(manifest)); commit(self.root,"commit empty subtree disposition")
        result=self.invoke("--dispositions","dispositions.json","--strict")
        self.assertEqual(result.returncode,2,result.stderr)
        self.assertIn("retired subtree has no historical paths",result.stderr)


    def test_dot_segment_disposition_path_fails_closed(self):
        folder=self.root/"config/hypr"; folder.mkdir(parents=True)
        old=folder/"old.conf"; old.write_text("old\\n"); commit(self.root,"historical path")
        old.unlink(); (folder/"current.lua").write_text("return true\\n"); commit(self.root,"replace historical path")
        manifest={"config/hypr/./old.conf":{"status":"authorized-retired","user_authorization":True,"evidence":"unsafe path"}}
        (self.root/"dispositions.json").write_text(json.dumps(manifest)); commit(self.root,"commit unsafe path manifest")
        result=self.invoke("--dispositions","dispositions.json")
        self.assertEqual(result.returncode,2)
        self.assertIn("invalid repository-relative disposition path",result.stderr)

    def test_overlapping_authorized_subtrees_fail_closed(self):
        folder=self.root/"config/hypr/legacy/child"; folder.mkdir(parents=True)
        old=folder/"old.conf"; old.write_text("old\\n"); commit(self.root,"historical nested path")
        old.unlink(); (self.root/"config/hypr/current.lua").write_text("return true\\n"); commit(self.root,"remove nested path")
        evidence={"status":"authorized-retired","evidence":"synthetic explicit authorization","user_authorization":True}
        manifest={"authorized_subtrees":[dict({"path":"config/hypr/legacy"},**evidence),dict({"path":"config/hypr/legacy/child"},**evidence)]}
        (self.root/"dispositions.json").write_text(json.dumps(manifest)); commit(self.root,"commit overlapping subtree manifest")
        result=self.invoke("--dispositions","dispositions.json")
        self.assertEqual(result.returncode,2)
        self.assertIn("overlapping subtree retirement",result.stderr)

if __name__=="__main__": unittest.main(verbosity=2)

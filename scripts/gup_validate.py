#!/usr/bin/env python3
"""Validate a GUP v7 evidence bundle against its declared baseline/candidate and gates.

The validator does not infer semantic correctness. It verifies that required proof records
are complete, unique, correctly scoped, evidence-backed, and consistent with the clean Git
candidate. Human-reviewed semantic and architecture judgments remain explicit obligations.
"""
from __future__ import annotations
import argparse, hashlib, json, os, re, subprocess, sys, tempfile
from pathlib import Path

VERSION="7.0.0"
SURFACES={"entry_points","loaders","callers","providers","consumers","configuration_paths","install_migration_paths","tests","runtime_dependencies"}
CLASSIFICATIONS={"UNCHANGED","CHANGED","NEW","MISSING"}

def git(root:Path,*args:str)->str:
    p=subprocess.run(["git","-C",str(root),*args],text=True,encoding="utf-8",stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=False,timeout=60)
    if p.returncode: raise RuntimeError(p.stderr.strip() or f"git {' '.join(args)} failed")
    return p.stdout.strip()

def nonempty(v): return isinstance(v,str) and bool(v.strip())
def atomic_write(path: Path, data: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd,name=tempfile.mkstemp(prefix=f".{path.name}.",suffix=".tmp",dir=path.parent); temp=Path(name)
    try:
        with os.fdopen(fd,"w",encoding="utf-8") as stream:
            stream.write(data); stream.flush(); os.fsync(stream.fileno())
        os.replace(temp,path)
        dfd=os.open(path.parent,os.O_RDONLY)
        try: os.fsync(dfd)
        finally: os.close(dfd)
    finally: temp.unlink(missing_ok=True)
def main()->int:
    p=argparse.ArgumentParser(description=__doc__); p.add_argument("--root",default="."); p.add_argument("--evidence",required=True); p.add_argument("--output"); a=p.parse_args(); root=Path(a.root).resolve(); errors=[]
    try:
        e=json.loads(Path(a.evidence).read_text(encoding="utf-8"))
        if not isinstance(e,dict): raise ValueError("evidence top-level value must be an object")
        if e.get("protocol_version")!=VERSION: errors.append(f"protocol_version must be {VERSION}")
        try: head=git(root,"rev-parse","HEAD")
        except RuntimeError as exc: raise ValueError(f"candidate repository is unavailable: {exc}")
        if e.get("candidate_commit")!=head: errors.append("candidate_commit does not equal current HEAD")
        if not isinstance(e.get("baseline_commit"),str) or not re.fullmatch(r"[0-9a-f]{40,64}",e["baseline_commit"]): errors.append("baseline_commit must be a full lowercase Git object ID")
        if e.get("baseline_commit")==head: errors.append("baseline and candidate commits are identical; no revision was evaluated")
        status=git(root,"status","--porcelain=v1","--untracked-files=all")
        if status: errors.append("worktree is dirty; certification requires a committed candidate")

        units=e.get("units")
        if not isinstance(units,dict): errors.append("units must be an object")
        else:
            for key in ("baseline_manifest","candidate_manifest","comparison_artifact"):
                if not nonempty(units.get(key)): errors.append(f"units.{key} is missing")
            if isinstance(units.get("baseline_manifest"),str) and Path(units["baseline_manifest"]).is_file():
                try: baseline=json.loads(Path(units["baseline_manifest"]).read_text(encoding="utf-8"))
                except (OSError,json.JSONDecodeError): errors.append("baseline_manifest is not readable valid JSON"); baseline={}
            else: baseline={}
            if isinstance(units.get("candidate_manifest"),str) and Path(units["candidate_manifest"]).is_file():
                try: candidate=json.loads(Path(units["candidate_manifest"]).read_text(encoding="utf-8"))
                except (OSError,json.JSONDecodeError): errors.append("candidate_manifest is not readable valid JSON"); candidate={}
            else: candidate={}
            if baseline and candidate:
                for name,data in (("baseline",baseline),("candidate",candidate)):
                    if not isinstance(data,dict) or not isinstance(data.get("units"),list): errors.append(f"{name} manifest must contain a units array"); continue
                    ids=[u.get("id") for u in data["units"] if isinstance(u,dict)]
                    if len(ids)!=len(data["units"]): errors.append(f"{name} manifest contains malformed units")
                    if len(set(ids))!=len(ids): errors.append(f"{name} manifest contains duplicate unit IDs")
                    if data.get("commit") != (e.get("baseline_commit") if name == "baseline" else head): errors.append(f"{name} manifest commit does not match declared Git lineage")
                    for unit in data["units"]:
                        if not isinstance(unit,dict) or not nonempty(unit.get("id")) or not isinstance(unit.get("sha256"),str) or not re.fullmatch(r"[0-9a-f]{64}",unit["sha256"]):
                            errors.append(f"{name} manifest unit requires stable id and lowercase SHA-256")
                comparison=e.get("comparison")
                if isinstance(comparison,list):
                    expected={}
                    b={u.get("id"):u for u in baseline.get("units",[]) if isinstance(u,dict)}
                    c={u.get("id"):u for u in candidate.get("units",[]) if isinstance(u,dict)}
                    for uid in sorted(set(b)|set(c)):
                        bh=b.get(uid,{}).get("sha256"); ch=c.get(uid,{}).get("sha256")
                        expected[uid]="MISSING" if uid in b and uid not in c else "NEW" if uid not in b else "UNCHANGED" if bh==ch else "CHANGED"
                    seen={}
                    for row in comparison:
                        if not isinstance(row,dict) or not nonempty(row.get("unit_id")) or row.get("classification") not in CLASSIFICATIONS:
                            errors.append("comparison contains malformed row"); continue
                        uid=row["unit_id"]
                        if uid in seen: errors.append(f"duplicate comparison row for {uid}")
                        seen[uid]=row["classification"]
                    if seen!=expected: errors.append("comparison rows do not exactly match baseline/candidate manifests")
                else: errors.append("comparison must be an array of {unit_id, classification} records")

        comparison=e.get("comparison") if isinstance(e.get("comparison"),list) else []
        reviews=e.get("semantic_reviews")
        if not isinstance(reviews,list): errors.append("semantic_reviews must be an array"); reviews=[]
        expected_review={r.get("unit_id") for r in comparison if isinstance(r,dict) and r.get("classification") in {"CHANGED","NEW","MISSING"}}
        seen_review=set()
        for i,r in enumerate(reviews):
            if not isinstance(r,dict): errors.append(f"semantic_reviews[{i}] malformed"); continue
            uid=r.get("unit_id")
            if not nonempty(uid): errors.append(f"semantic_reviews[{i}] missing unit_id"); continue
            if uid in seen_review: errors.append(f"duplicate semantic review for {uid}")
            seen_review.add(uid)
            if r.get("classification") not in CLASSIFICATIONS: errors.append(f"{uid}: invalid classification")
            if not nonempty(r.get("verdict")) or not nonempty(r.get("rationale")) or not nonempty(r.get("evidence")): errors.append(f"{uid}: verdict, rationale, and evidence are required")
            if r.get("classification")=="MISSING":
                if r.get("verdict")!="AUTHORIZED_REMOVAL" or r.get("user_authorization") is not True: errors.append(f"{uid}: missing baseline unit requires explicit user-authorized removal")
            elif r.get("classification") in {"CHANGED","NEW"} and r.get("verdict") not in {"PRESERVED_SUPERSET","ACCEPTED_NEW_CAPABILITY"}:
                errors.append(f"{uid}: CHANGED/NEW unit lacks accepted superset/architecture verdict")
        if seen_review!=expected_review: errors.append("semantic reviews do not exactly cover CHANGED/NEW/MISSING units")

        alignment=e.get("alignment")
        if not isinstance(alignment,dict) or alignment.get("status")!="PASS" or not nonempty(alignment.get("evidence")):
            errors.append("bidirectional alignment must be PASS with evidence")
        architecture=e.get("architecture_gate")
        if not isinstance(architecture,dict) or architecture.get("status")!="PASS" or not nonempty(architecture.get("evidence")):
            errors.append("architectural soundness gate must be PASS with evidence")
        closures=e.get("integration_closure")
        if not isinstance(closures,list): errors.append("integration_closure must be an array"); closures=[]
        closure_map={}
        for i,c in enumerate(closures):
            if not isinstance(c,dict) or not nonempty(c.get("surface")): errors.append(f"integration_closure[{i}] malformed"); continue
            surface=c["surface"]
            if surface in closure_map: errors.append(f"duplicate integration surface {surface}")
            closure_map[surface]=c
            if c.get("status") not in {"CLOSED","NOT_APPLICABLE"}: errors.append(f"integration surface {surface} is unresolved")
            if not nonempty(c.get("evidence")): errors.append(f"integration surface {surface} lacks evidence")
            if c.get("status")=="NOT_APPLICABLE" and not nonempty(c.get("rationale")): errors.append(f"integration surface {surface} N/A lacks rationale")
        if set(closure_map)!=SURFACES: errors.append(f"integration surfaces must exactly equal {sorted(SURFACES)}")
        targets=e.get("manifest_targets")
        if not isinstance(targets,list): errors.append("manifest_targets must be an array"); targets=[]
        for i,t in enumerate(targets):
            if not isinstance(t,dict) or not nonempty(t.get("target")) or t.get("status") not in {"CLOSED","BLOCKED","NOT_APPLICABLE"} or not nonempty(t.get("evidence")):
                errors.append(f"manifest_targets[{i}] needs target, valid status, and evidence")
        if any(isinstance(t,dict) and t.get("status")=="BLOCKED" for t in targets): errors.append("one or more manifest targets remain BLOCKED")
        tests=e.get("tests")
        if not isinstance(tests,list) or not tests: errors.append("tests must contain at least one executed test record"); tests=[]
        for i,t in enumerate(tests):
            if not isinstance(t,dict) or not nonempty(t.get("command")) or t.get("exit_code")!=0 or not nonempty(t.get("evidence")):
                errors.append(f"tests[{i}] must prove an executed command with exit_code 0 and evidence")
        result={"schema_version":1,"protocol":"GUP","protocol_version":VERSION,"candidate_commit":head,"status":"FAIL" if errors else "PASS","error_count":len(errors),"errors":errors}
        encoded=json.dumps(result,indent=2,sort_keys=True)+"\n"
        if a.output: atomic_write(Path(a.output),encoded)
        else: print(encoded,end="")
        return 1 if errors else 0
    except (OSError,ValueError,json.JSONDecodeError,RuntimeError,subprocess.SubprocessError) as exc:
        print(f"GUP validator failed closed: {exc}",file=sys.stderr); return 2
if __name__=="__main__": raise SystemExit(main())

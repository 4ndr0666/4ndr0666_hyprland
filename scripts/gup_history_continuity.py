#!/usr/bin/env python3
"""Inventory historical Git paths, blob identities, commit lineage, and rename evidence."""
from __future__ import annotations
import argparse, json, subprocess, sys, tempfile, os
from pathlib import Path

EXCLUDED_PARTS={".git","node_modules",".venv","vendor",".bak","backup","backups","archive","legacy-conf-backup"}
def git(root:Path,*args:str)->bytes:
    p=subprocess.run(["git","-C",str(root),*args],stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=False,timeout=180)
    if p.returncode: raise RuntimeError(p.stderr.decode("utf-8","replace").strip() or f"git {' '.join(args)} failed")
    return p.stdout

def history_events(root:Path,scope:str):
    raw=git(root,"log","--all","--full-history","--find-renames","--name-status","--format=%H%x09%ct%x09%s","--",scope).decode("utf-8","replace")
    commits=[]; renames=[]; current=None
    for line in raw.splitlines():
        if not line: continue
        pieces=line.split("\t")
        if len(pieces)>=3 and len(pieces[0]) in (40,64) and pieces[0].isalnum() and pieces[1].isdigit():
            current={"sha":pieces[0],"timestamp":int(pieces[1]),"subject":"\t".join(pieces[2:])}; commits.append(current); continue
        if current is not None and len(pieces)>=3 and pieces[0].startswith("R"):
            renames.append({"commit":current["sha"],"similarity":pieces[0][1:],"previous_path":pieces[1],"path":"\t".join(pieces[2:])})
    return commits,renames

def main()->int:
    p=argparse.ArgumentParser(description=__doc__); p.add_argument("--root",default="."); p.add_argument("--scope",default="."); p.add_argument("--dispositions"); p.add_argument("--strict",action="store_true"); p.add_argument("--output"); a=p.parse_args(); root=Path(a.root).resolve(); scope=a.scope.rstrip("/") or "."
    try:
        objects=git(root,"rev-list","--objects","--all","--",scope).decode("utf-8","replace").splitlines()
        parsed=[]
        for line in objects:
            parts=line.split(" ",1)
            if len(parts)==2 and parts[1] and not parts[1].startswith("("): parsed.append((parts[0],parts[1]))
        # One batch type query avoids a process per historical object.
        proc=subprocess.run(["git","-C",str(root),"cat-file","--batch-check"],input=("\n".join(oid for oid,_ in parsed)+"\n").encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=False,timeout=180)
        if proc.returncode: raise RuntimeError(proc.stderr.decode("utf-8","replace"))
        blob_ids=set()
        for (oid,path),info in zip(parsed,proc.stdout.decode("utf-8","replace").splitlines()):
            parts=info.split()
            if len(parts)>=3 and parts[1]=="blob": blob_ids.add((oid,path))
        historical={}
        for oid,path in blob_ids:
            historical.setdefault(path,set()).add(oid)
        current={x.decode("utf-8","surrogateescape") for x in git(root,"ls-files","-z","--",scope).split(b"\0") if x}
        dispositions={}
        if a.dispositions:
            dispositions=json.loads((root/a.dispositions).read_text(encoding="utf-8"))
            if not isinstance(dispositions,dict): raise ValueError("dispositions must be an object keyed by historical path")
        allowed={"preserved","translated","authorized-retired"}
        for path,item in dispositions.items():
            if not isinstance(item,dict) or item.get("status") not in allowed or not isinstance(item.get("evidence"),str) or not item["evidence"].strip(): raise ValueError(f"invalid disposition for {path}")
            if item["status"]=="translated" and (not isinstance(item.get("target"),str) or not item["target"].strip()): raise ValueError(f"translated disposition for {path} needs target")
            if item["status"]=="authorized-retired" and item.get("user_authorization") is not True: raise ValueError(f"retirement of {path} requires explicit user_authorization=true")
        commits,renames=history_events(root,scope); records=[]
        for path in sorted(set(historical)|current):
            if any(part in EXCLUDED_PARTS for part in Path(path).parts): continue
            present=path in current; status="present-path" if present else dispositions.get(path,{}).get("status","unresolved-missing")
            records.append({"path":path,"status":status,"current":present,"historical_object_ids":sorted(historical.get(path,set())),"disposition":dispositions.get(path)})
        unresolved=[r for r in records if r["status"]=="unresolved-missing"]
        report={"schema_version":1,"protocol":"GUP","scope":scope,"head":git(root,"rev-parse","HEAD").decode().strip(),"refs":git(root,"for-each-ref","--format=%(refname):%(objectname)").decode().splitlines(),"commit_count":len(commits),"commits":commits,"rename_event_count":len(renames),"rename_events":renames,"historical_path_count":len(historical),"current_path_count":len(current),"record_count":len(records),"unresolved_missing_count":len(unresolved),"records":records}
        encoded=(json.dumps(report,indent=2,sort_keys=True)+"\n").encode()
        if a.output:
            target=Path(a.output); target.parent.mkdir(parents=True,exist_ok=True); fd,name=tempfile.mkstemp(prefix=f".{target.name}.",suffix=".tmp",dir=target.parent); temp=Path(name)
            try:
                with os.fdopen(fd,"wb") as f: f.write(encoded); f.flush(); os.fsync(f.fileno())
                os.replace(temp,target)
                dfd=os.open(target.parent,os.O_RDONLY)
                try: os.fsync(dfd)
                finally: os.close(dfd)
            finally: temp.unlink(missing_ok=True)
        else: sys.stdout.buffer.write(encoded)
        if a.strict and unresolved: print(f"GUP continuity: FAIL — {len(unresolved)} unresolved historical paths",file=sys.stderr); return 1
        return 0
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError,json.JSONDecodeError) as exc:
        print(f"GUP continuity inventory failed: {exc}",file=sys.stderr); return 2
if __name__=="__main__": raise SystemExit(main())

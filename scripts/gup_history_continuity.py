#!/usr/bin/env python3
"""Inventory historical Git paths, blob identities, commit lineage, and rename evidence."""
from __future__ import annotations
import argparse, json, subprocess, sys, tempfile, os
from pathlib import Path, PurePosixPath

def git(root:Path,*args:str)->bytes:
    p=subprocess.run(["git","-C",str(root),*args],stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=False,timeout=180)
    if p.returncode: raise RuntimeError(p.stderr.decode("utf-8","replace").strip() or f"git {' '.join(args)} failed")
    return p.stdout

def history_events(root:Path,scope:str):
    raw=git(root,"log","--all","HEAD","--full-history","--find-renames","--name-status","--format=%H%x09%ct%x09%s","--",scope).decode("utf-8","replace")
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
        scope_path=PurePosixPath(scope)
        if scope != "." and (scope_path.is_absolute() or any(part in {"", ".", ".."} for part in scope_path.parts)):
            raise ValueError("scope must be repository-relative and cannot contain parent traversal")
        commit_ids=git(root,"rev-list","--topo-order","--all","HEAD").decode("ascii").splitlines()
        if not commit_ids: raise ValueError("no reachable commits; continuity cannot be established")
        historical={}
        for commit_id in commit_ids:
            raw_tree=git(root,"ls-tree","-r","-z","--full-tree",commit_id,"--",scope)
            for record in raw_tree.split(b"\\0"):
                if not record: continue
                header,separator,path_bytes=record.partition(b"\\t")
                fields=header.split()
                if not separator or len(fields)!=3: raise ValueError(f"malformed tree record in {commit_id}")
                mode,kind,oid=(field.decode("ascii") for field in fields)
                if kind=="blob":
                    path=path_bytes.decode("utf-8","surrogateescape")
                    historical.setdefault(path,set()).add(oid)
        current_tree=git(root,"ls-tree","-r","-z","--full-tree","HEAD","--",scope)
        current=set()
        for record in current_tree.split(b"\\0"):
            if not record: continue
            _,separator,path_bytes=record.partition(b"\\t")
            if not separator: raise ValueError("malformed candidate HEAD tree record")
            current.add(path_bytes.decode("utf-8","surrogateescape"))
        dispositions={}
        if a.dispositions:
            manifest_path=PurePosixPath(a.dispositions)
            if manifest_path.is_absolute() or any(part in {"", ".", ".."} for part in manifest_path.parts):
                raise ValueError("disposition manifest must be a safe repository-relative path")
            raw=json.loads(git(root,"show",f"HEAD:{a.dispositions}").decode("utf-8"))
            if not isinstance(raw,dict): raise ValueError("dispositions must be a JSON object")
            allowed={"preserved","translated","authorized-retired"}
            subtrees=raw.get("authorized_subtrees",[])
            if not isinstance(subtrees,list): raise ValueError("authorized_subtrees must be an array")
            for entry in subtrees:
                if not isinstance(entry,dict): raise ValueError("authorized subtree entries must be objects")
                base=entry.get("path")
                base_path=PurePosixPath(base) if isinstance(base,str) else None
                if (base_path is None or not base or base_path.is_absolute()
                        or any(part in {"", ".", ".."} for part in base_path.parts)
                        or (scope != "." and not base.startswith(scope+"/"))):
                    raise ValueError(f"invalid authorized subtree: {base!r}")
                if entry.get("status")!="authorized-retired" or entry.get("user_authorization") is not True:
                    raise ValueError(f"subtree retirement requires explicit authorization: {base}")
                evidence=entry.get("evidence")
                if not isinstance(evidence,str) or not evidence.strip():
                    raise ValueError(f"subtree retirement requires evidence: {base}")
                matched=[path for path in historical if path.startswith(base+"/")]
                if not matched: raise ValueError(f"authorized subtree has no historical paths: {base}")
                if any(path.startswith(base+"/") for path in current):
                    raise ValueError(f"authorized subtree contains current tracked paths: {base}")
                for path in matched:
                    if path in dispositions: raise ValueError(f"overlapping authorized subtree: {path}")
                    dispositions[path]={"status":"authorized-retired","user_authorization":True,"evidence":evidence,"authorization_scope":base}
            for path,item in raw.items():
                if path in {"schema_version","authorized_subtrees"}: continue
                path_obj=PurePosixPath(path) if isinstance(path,str) else None
                if (path_obj is None or not path or path_obj.is_absolute()
                        or any(part in {"", ".", ".."} for part in path_obj.parts)
                        or (scope != "." and not (path==scope or path.startswith(scope+"/"))):
                    raise ValueError(f"invalid or out-of-scope disposition path: {path!r}")
                if path not in historical: raise ValueError(f"disposition path absent from Git history: {path!r}")
                if path in current: raise ValueError(f"disposition path is still present at HEAD: {path!r}")
                if not isinstance(item,dict) or item.get("status") not in allowed:
                    raise ValueError(f"invalid disposition for {path!r}")
                if not isinstance(item.get("evidence"),str) or not item["evidence"].strip():
                    raise ValueError(f"missing disposition evidence: {path!r}")
                if item["status"] in {"preserved","translated"} and item.get("target") not in current:
                    raise ValueError(f"disposition target is not tracked at HEAD: {path!r} -> {item.get('target')!r}")
                if item["status"]=="authorized-retired" and item.get("user_authorization") is not True:
                    raise ValueError(f"retirement requires user_authorization=true: {path}")
                if path in dispositions: raise ValueError(f"overlapping subtree and individual dispositions: {path!r}")
                dispositions[path]=item
        commits,renames=history_events(root,scope); records=[]
        for path in sorted(set(historical)|current):
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

#!/usr/bin/env python3
"""Build independently recomputable continuity evidence from reachable Git history."""
from __future__ import annotations
import argparse, hashlib, json, os, subprocess, sys, tempfile
from pathlib import Path, PurePosixPath
from typing import Any

ARCHIVE_PARTS = {".bak", "backup", "backups", "archive", "archives", "legacy-conf-backup"}

def archive_path(path: str) -> bool:
    parts = PurePosixPath(path).parts
    return any(part.lower() in ARCHIVE_PARTS
               or part.lower().endswith((".bak", ".backup", "~", ".gup.tmp"))
               or ".bak." in part.lower() for part in parts)

def git(root: Path, *args: str, input_bytes: bytes | None = None) -> bytes:
    p = subprocess.run(["git", "-C", str(root), *args], input=input_bytes, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=180)
    if p.returncode:
        raise RuntimeError(p.stderr.decode("utf-8", "replace").strip() or f"git {' '.join(args)} failed")
    return p.stdout

def validate_scope(scope: str) -> str:
    s=scope.strip("/"); p=PurePosixPath(s)
    if not s or p.is_absolute() or any(x in {"", ".", ".."} for x in p.parts):
        raise ValueError("scope must be repository-relative and cannot contain '.' or '..'")
    return s

def tree(root: Path, commit: str, scope: str) -> list[dict[str,str]]:
    raw=git(root,"ls-tree","-r","-z","--full-tree",commit,"--",scope); rows=[]
    for record in raw.split(b"\0"):
        if not record: continue
        header,sep,path=record.partition(b"\t"); fields=header.split()
        if not sep or len(fields)!=3: raise ValueError(f"malformed tree record in {commit}")
        mode,kind,oid=(x.decode("ascii") for x in fields)
        if kind=="blob": rows.append({"path":path.decode("utf-8","surrogateescape"),"mode":mode,"oid":oid})
    return rows

def metadata(root: Path, commits: list[str]) -> list[dict[str,Any]]:
    rows=[]
    for oid in commits:
        raw=git(root,"show","-s","--format=%H%x00%P%x00%ct%x00%s",oid).decode("utf-8","surrogateescape").rstrip("\n")
        f=raw.split("\0",3)
        if len(f)!=4 or f[0]!=oid: raise ValueError(f"cannot reconstruct commit metadata: {oid}")
        rows.append({"commit":f[0],"parents":f[1].split() if f[1] else [],"timestamp":int(f[2]),"subject":f[3]})
    return rows

def renames(root: Path, commits: list[dict[str,Any]], scope: str) -> list[dict[str,str]]:
    events=[]
    for c in commits:
        for parent in c["parents"]:
            raw=git(root,"diff-tree","--no-commit-id","--name-status","-r","-M","-z",parent,c["commit"],"--",scope)
            f=raw.split(b"\0"); i=0
            while i<len(f) and f[i]:
                status=f[i].decode("ascii","replace"); i+=1
                count=2 if status.startswith(("R","C")) else 1
                if i+count>len(f): raise ValueError(f"truncated diff-tree record: {c['commit']}")
                paths=[f[i+j].decode("utf-8","surrogateescape") for j in range(count)]; i+=count
                if status.startswith("R"):
                    events.append({"commit":c["commit"],"parent":parent,"status":status,"similarity":status[1:],"previous_path":paths[0],"path":paths[1]})
    return events

def dispositions(root: Path, filename: str|None, scope: str, historical: set[str], current: set[str]):
    if not filename: return {}, None
    manifest_path = PurePosixPath(filename)
    if manifest_path.is_absolute() or any(part in {"", ".", ".."} for part in manifest_path.parts):
        raise ValueError("disposition manifest must be a safe repository-relative path")
    manifest_bytes = git(root, "show", f"HEAD:{filename}")
    raw=json.loads(manifest_bytes.decode("utf-8"))
    manifest_pin = {"path": filename, "git_object_id": git(root, "rev-parse", f"HEAD:{filename}").decode().strip(),
                    "sha256": hashlib.sha256(manifest_bytes).hexdigest(), "source": "HEAD Git object"}
    if not isinstance(raw,dict): raise ValueError("disposition manifest must be an object")
    result={}; allowed={"preserved","translated","authorized-retired"}
    for entry in raw.get("authorized_subtrees",[]):
        if not isinstance(entry,dict): raise ValueError("authorized_subtrees entries must be objects")
        base=entry.get("path")
        if not isinstance(base,str) or not base.startswith(scope+"/"): raise ValueError(f"invalid retired subtree: {base!r}")
        if entry.get("status")!="authorized-retired" or entry.get("user_authorization") is not True: raise ValueError(f"retirement requires explicit authorization: {base}")
        if not isinstance(entry.get("evidence"),str) or not entry["evidence"].strip(): raise ValueError(f"retirement requires evidence: {base}")
        if any(p.startswith(base+"/") for p in current): raise ValueError(f"retired subtree has current paths: {base}")
        for path in historical:
            if path.startswith(base+"/"):
                result[path]={"status":"authorized-retired","user_authorization":True,"evidence":entry["evidence"],"authorization_scope":base}
    for path,item in raw.items():
        if path in {"schema_version","authorized_subtrees"}: continue
        if not isinstance(path,str) or not (path==scope or path.startswith(scope+"/")): raise ValueError(f"disposition outside scope: {path!r}")
        if path not in historical: raise ValueError(f"disposition path absent from Git history: {path!r}")
        if path in current: raise ValueError(f"disposition is only valid for a missing current path: {path!r}")
        if not isinstance(item,dict) or item.get("status") not in allowed: raise ValueError(f"invalid disposition: {path}")
        if not isinstance(item.get("evidence"),str) or not item["evidence"].strip(): raise ValueError(f"missing evidence: {path}")
        if item["status"] in {"preserved", "translated"}:
            target=item.get("target")
            label=f"{item['status']} target"
            if not isinstance(target,str) or not target.strip() or target not in current:
                raise ValueError(f"{label} is not current: {path} -> {target!r}")
        if item["status"]=="authorized-retired" and item.get("user_authorization") is not True:
            raise ValueError(f"retirement requires user_authorization=true: {path}")
        if path in result: raise ValueError(f"path has overlapping subtree and individual dispositions: {path!r}")
        result[path]=item
    return result, manifest_pin

def atomic_write(target: Path, data: bytes) -> None:
    target.parent.mkdir(parents=True,exist_ok=True)
    fd,name=tempfile.mkstemp(prefix=f".{target.name}.",suffix=".tmp",dir=target.parent); tmp=Path(name)
    try:
        with os.fdopen(fd,"wb") as stream:
            stream.write(data); stream.flush(); os.fsync(stream.fileno())
        os.replace(tmp,target); dfd=os.open(target.parent,os.O_RDONLY)
        try: os.fsync(dfd)
        finally: os.close(dfd)
    finally: tmp.unlink(missing_ok=True)

def main() -> int:
    p=argparse.ArgumentParser(description=__doc__); p.add_argument("--root",default="."); p.add_argument("--scope",default="config/hypr")
    p.add_argument("--dispositions"); p.add_argument("--strict",action="store_true"); p.add_argument("--output"); a=p.parse_args(); root=Path(a.root).resolve()
    try:
        scope=validate_scope(a.scope)
        shallow=git(root,"rev-parse","--is-shallow-repository").decode().strip()=="true"
        refs=git(root,"for-each-ref","--format=%(refname)%09%(objectname)").decode("utf-8","replace").splitlines()
        commit_ids=git(root,"rev-list","--topo-order","--all","HEAD").decode("ascii").splitlines()
        if not commit_ids: raise ValueError("no reachable commits; continuity cannot be established")
        commits=metadata(root,commit_ids); versions:dict[str,list[dict[str,str]]]={}; blob_ids=set()
        for cid in commit_ids:
            for item in tree(root,cid,scope):
                pin={"commit":cid,"path":item["path"],"mode":item["mode"],"git_object_id":item["oid"],"git_show_spec":f"{cid}:{item['path']}"}
                versions.setdefault(item["path"],[]).append(pin); blob_ids.add(item["oid"])
        blob_pins={}
        for oid in sorted(blob_ids):
            content=git(root,"cat-file","blob",oid)
            recomputed=git(root,"hash-object","--stdin",input_bytes=content).decode("ascii").strip()
            if recomputed!=oid: raise ValueError(f"Git blob hash mismatch: {oid} recomputed as {recomputed}")
            blob_pins[oid]={"git_object_id":oid,"git_object_type":"blob","byte_length":len(content),"sha256":hashlib.sha256(content).hexdigest(),"git_object_id_recomputed":recomputed,"content_recomputable":True}
        head=git(root,"rev-parse","HEAD").decode().strip(); current={x["path"] for x in tree(root,head,scope)}
        historical=set(versions); disp, manifest_pin=dispositions(root,a.dispositions,scope,historical,current); records=[]
        for path in sorted(historical|current):
            present=path in current; archived=archive_path(path); item=disp.get(path); rows=versions.get(path,[])
            if item and item["status"]=="authorized-retired": status="authorized-retired"
            elif archived: status="archive-path-present" if present else "archive-path-missing"
            elif item: status=item["status"]
            elif present: status="present-path"
            else: status="unresolved-missing"
            records.append({"path":path,"scope_class":"archive" if archived else "active","status":status,"present_at_head":present,"historical_commit_count":len(rows),"historical_blob_ids":sorted({x["git_object_id"] for x in rows}),"versions":rows,"disposition":item})
        unresolved=[x for x in records if x["scope_class"]=="active" and x["status"]=="unresolved-missing"]; rename_rows=renames(root,commits,scope)
        report={"schema_version":1,"protocol":"GUP","evidence_kind":"repository-derived-rehydration-verification","scope":scope,"head":head,
                "object_format":git(root,"rev-parse","--show-object-format").decode().strip(),"shallow_repository":shallow,"refs":refs,
                "reachable_commit_count":len(commits),"commits":commits,"historical_path_count":len(historical),"current_path_count":len(current),"archive_path_count":sum(1 for x in records if x["scope_class"]=="archive"),
                "historical_path_version_count":sum(map(len,versions.values())),"rename_event_count":len(rename_rows),"rename_events":rename_rows,
                "blob_count":len(blob_pins),"blob_pins":blob_pins,"path_records":records,"dispositions_manifest":manifest_pin,"unresolved_missing_count":len(unresolved),
                "verification":{"all_blob_git_ids_recomputed":all(x["git_object_id"]==x["git_object_id_recomputed"] for x in blob_pins.values()),
                                "all_blob_sha256_pinned":all(len(x["sha256"])==64 for x in blob_pins.values()),"all_historical_path_versions_recorded":True,"shallow_history_blocks_strict":shallow}}
        encoded=(json.dumps(report,indent=2,sort_keys=True,ensure_ascii=True)+"\n").encode()
        if a.output: atomic_write(Path(a.output),encoded)
        else: sys.stdout.buffer.write(encoded)
        if a.strict and (unresolved or shallow):
            print(f"GUP rehydration verification: FAIL — unresolved paths={len(unresolved)}, shallow_history={shallow}",file=sys.stderr); return 1
        print(f"GUP rehydration verification: {'FAIL' if shallow else 'PASS'} — commits={len(commits)}, paths={len(historical)}, blobs={len(blob_pins)}, unresolved={len(unresolved)}",file=sys.stderr)
        return 1 if shallow else 0
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError,json.JSONDecodeError) as exc:
        print(f"GUP rehydration verification failed: {exc}",file=sys.stderr); return 2
if __name__=="__main__": raise SystemExit(main())

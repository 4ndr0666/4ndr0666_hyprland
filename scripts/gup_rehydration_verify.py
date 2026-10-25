#!/usr/bin/env python3
"""Build independently recomputable continuity evidence from reachable Git history."""
from __future__ import annotations
import argparse, hashlib, json, os, subprocess, sys, tempfile
from pathlib import Path
from typing import Any

def git(root: Path, *args: str) -> bytes:
    p = subprocess.run(["git", "-C", str(root), *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=180)
    if p.returncode:
        raise RuntimeError(p.stderr.decode("utf-8", "replace").strip() or f"git {' '.join(args)} failed")
    return p.stdout

def validate_repo_path(path: str, label: str) -> str:
    if (not isinstance(path, str) or not path or path.startswith("/") or "\\" in path
            or any(part in {"", ".", ".."} for part in path.split("/"))):
        raise ValueError(f"invalid repository-relative {label}: {path!r}")
    return path

def validate_scope(scope: str) -> str:
    if scope == ".":
        return scope
    return validate_repo_path(scope, "scope")

def tree(root: Path, commit: str, scope: str) -> list[dict[str,str]]:
    args=["ls-tree","-r","-z","--full-tree",commit]
    if scope != ".": args.extend(["--",scope])
    raw=git(root,*args); rows=[]
    for record in raw.split(b"\0"):
        if not record: continue
        header,sep,path=record.partition(b"\t"); fields=header.split()
        if not sep or len(fields)!=3: raise ValueError(f"malformed tree record in {commit}")
        mode,kind,oid=(x.decode("ascii") for x in fields)
        if kind=="blob": rows.append({"path":path.decode("utf-8","surrogateescape"),"mode":mode,"oid":oid})
    return rows

def metadata(root: Path) -> list[dict[str,Any]]:
    # One Git traversal replaces two subprocesses per commit. Record separators
    # are control bytes, so commit subjects cannot ambiguously split records.
    raw=git(root,"log","--topo-order","--full-history","--exclude=refs/stash","--all",
            "--format=%H%x00%T%x00%P%x00%ct%x00%s%x1e")
    rows=[]
    for record in raw.split(b"\x1e"):
        if not record.strip(): continue
        fields=record.strip(b"\n").split(b"\0",4)
        if len(fields)!=5: raise ValueError("cannot parse batched commit metadata")
        commit_oid,tree_oid,parents,timestamp,subject=(x.decode("utf-8","surrogateescape") for x in fields)
        rows.append({"commit":commit_oid,"tree_object_id":tree_oid,"parents":parents.split() if parents else [],
                     "timestamp":int(timestamp),"subject":subject})
    if not rows: raise ValueError("no reachable commits; continuity cannot be established")
    return rows

def reachable_object_ids(root: Path, refs: list[str]) -> list[str]:
    """Enumerate objects reachable from accepted refs, excluding refs/stash.

    rev-list supplies commits, trees, and blobs across every accepted ref.
    Direct ref targets are added separately so annotated tag objects are not
    omitted by revision traversal. Nested annotated tags are followed until
    their target is no longer a tag.
    """
    raw = git(root, "rev-list", "--objects", "--exclude=refs/stash", "--all", "HEAD")
    object_ids = {line.split(None, 1)[0].decode("ascii") for line in raw.splitlines() if line.strip()}
    ref_rows = []
    for line in refs:
        name, separator, oid = line.partition("\t")
        if not separator or not name.startswith(("refs/heads/", "refs/tags/", "refs/remotes/")):
            raise ValueError(f"malformed accepted ref record: {line!r}")
        ref_rows.append((name, oid))
        object_ids.add(oid)

    # Annotated tag objects are themselves reachable objects. Revision walks
    # peel tags for commit traversal, so retain every tag object and any tag
    # object it directly references. The chain is cycle-guarded defensively.
    pending = [oid for name, oid in ref_rows if name.startswith("refs/tags/")]
    visited_tags: set[str] = set()
    while pending:
        oid = pending.pop()
        if oid in visited_tags:
            continue
        kind = git(root, "cat-file", "-t", oid).decode("ascii").strip()
        if kind != "tag":
            continue
        visited_tags.add(oid)
        payload = git(root, "cat-file", "tag", oid)
        first_line = payload.split(b"\n", 1)[0]
        if not first_line.startswith(b"object "):
            raise ValueError(f"malformed annotated tag object: {oid}")
        target = first_line[len(b"object "):].decode("ascii")
        object_ids.add(target)
        pending.append(target)

    return sorted(object_ids)

def pin_objects(root: Path, object_ids: list[str], object_format: str, expected_types: dict[str, str]) -> dict[str, dict[str, Any]]:
    """Stream exact object payloads and recompute native IDs plus SHA-256 pins.

    The temporary input file avoids a stdin/stdout pipe deadlock while Git
    emits a large batch. Payloads are hashed incrementally and never retained
    in memory, keeping the full reachable object graph practical to verify.
    """
    if not object_ids:
        raise ValueError("no reachable Git objects; continuity cannot be established")
    pins: dict[str, dict[str, Any]] = {}
    with tempfile.TemporaryFile() as request:
        request.write(("\n".join(object_ids) + "\n").encode("ascii"))
        request.seek(0)
        process = subprocess.Popen(
            ["git", "-C", str(root), "cat-file", "--batch"],
            stdin=request, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        assert process.stdout is not None
        try:
            for expected_oid in object_ids:
                header = process.stdout.readline()
                if not header:
                    raise ValueError(f"truncated cat-file header for {expected_oid}")
                fields = header.rstrip(b"\n").split()
                if len(fields) != 3:
                    raise ValueError(f"missing or malformed Git object response for {expected_oid}")
                actual_oid, kind_bytes, size_bytes = fields
                actual = actual_oid.decode("ascii")
                kind = kind_bytes.decode("ascii")
                if actual != expected_oid:
                    raise ValueError(f"cat-file object order mismatch: expected {expected_oid}, got {actual}")
                size = int(size_bytes)
                if size < 0:
                    raise ValueError(f"negative Git object size for {expected_oid}")
                expected_kind = expected_types.get(expected_oid)
                if expected_kind is not None and kind != expected_kind:
                    raise ValueError(f"Git object type mismatch for {expected_oid}: expected {expected_kind}, got {kind}")
                native = hashlib.new(object_format)
                native.update(f"{kind} {size}\0".encode("ascii"))
                content_sha = hashlib.sha256()
                remaining = size
                while remaining:
                    chunk = process.stdout.read(min(1024 * 1024, remaining))
                    if not chunk:
                        raise ValueError(f"truncated Git object payload: {expected_oid}")
                    native.update(chunk)
                    content_sha.update(chunk)
                    remaining -= len(chunk)
                delimiter = process.stdout.read(1)
                if delimiter != b"\n":
                    raise ValueError(f"missing cat-file payload delimiter: {expected_oid}")
                recomputed = native.hexdigest()
                if recomputed != expected_oid:
                    raise ValueError(f"Git {kind} hash mismatch: {expected_oid} recomputed as {recomputed}")
                pins[expected_oid] = {
                    "git_object_id": expected_oid, "git_object_type": kind,
                    "byte_length": size, "sha256": content_sha.hexdigest(),
                    "git_object_id_recomputed": recomputed, "content_recomputable": True,
                }
            if process.stdout.read(1):
                raise ValueError("unexpected trailing bytes in cat-file batch output")
            stderr = process.stderr.read() if process.stderr is not None else b""
            return_code = process.wait(timeout=180)
            if return_code:
                raise RuntimeError(stderr.decode("utf-8", "replace").strip() or "git cat-file --batch failed")
        except BaseException:
            process.kill()
            process.wait()
            raise
        finally:
            if process.stdout is not None:
                process.stdout.close()
            if process.stderr is not None:
                process.stderr.close()
    return pins

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
    validate_repo_path(filename, "disposition manifest")
    manifest_bytes = git(root, "show", f"HEAD:{filename}")
    raw=json.loads(manifest_bytes.decode("utf-8"))
    manifest_pin = {"path": filename, "git_object_id": git(root, "rev-parse", f"HEAD:{filename}").decode().strip(),
                    "sha256": hashlib.sha256(manifest_bytes).hexdigest(), "source": "HEAD Git object"}
    if not isinstance(raw,dict): raise ValueError("disposition manifest must be an object")
    result={}; allowed={"preserved","translated","authorized-retired"}
    for entry in raw.get("authorized_subtrees",[]):
        if not isinstance(entry,dict): raise ValueError("authorized_subtrees entries must be objects")
        base=entry.get("path")
        validate_repo_path(base, "retired subtree")
        if scope != "." and not base.startswith(scope+"/"):
            raise ValueError(f"invalid retired subtree: {base!r}")
        if entry.get("status")!="authorized-retired" or entry.get("user_authorization") is not True: raise ValueError(f"retirement requires explicit authorization: {base}")
        if not isinstance(entry.get("evidence"),str) or not entry["evidence"].strip(): raise ValueError(f"retirement requires evidence: {base}")
        if any(p.startswith(base+"/") for p in current): raise ValueError(f"retired subtree has current paths: {base}")
        matched_paths = [path for path in historical if path.startswith(base+"/")]
        if not matched_paths: raise ValueError(f"retired subtree has no historical paths: {base}")
        for path in matched_paths:
            if path in result:
                raise ValueError(f"overlapping subtree retirement for path {path!r}")
            result[path]={"status":"authorized-retired","user_authorization":True,"evidence":entry["evidence"],"authorization_scope":base}
    for path,item in raw.items():
        if path in {"schema_version","authorized_subtrees"}: continue
        validate_repo_path(path, "disposition path")
        if scope != "." and not (path==scope or path.startswith(scope+"/")):
            raise ValueError(f"disposition outside scope or invalid path: {path!r}")
        if path not in historical: raise ValueError(f"disposition path absent from Git history: {path!r}")
        if path in current: raise ValueError(f"disposition is only valid for a missing current path: {path!r}")
        if not isinstance(item,dict) or item.get("status") not in allowed: raise ValueError(f"invalid disposition: {path}")
        if not isinstance(item.get("evidence"),str) or not item["evidence"].strip(): raise ValueError(f"missing evidence: {path}")
        if item["status"] in {"preserved", "translated"}:
            target=item.get("target")
            label=f"{item['status']} target"
            validate_repo_path(target, label)
            if target not in current:
                raise ValueError(f"{label} is not current: {path} -> {target!r}")
        if item["status"]=="authorized-retired" and item.get("user_authorization") is not True:
            raise ValueError(f"retirement requires user_authorization=true: {path}")
        if path in result:
            raise ValueError(f"path has overlapping subtree and individual dispositions: {path!r}")
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
        refs=git(root,"for-each-ref","--format=%(refname)%09%(objectname)","refs/heads","refs/tags","refs/remotes").decode("utf-8","replace").splitlines()
        commit_ids=git(root,"rev-list","--topo-order","--exclude=refs/stash","--all","HEAD").decode("ascii").splitlines()
        if not commit_ids: raise ValueError("no reachable commits; continuity cannot be established")
        commits=metadata(root)
        if {row["commit"] for row in commits}!=set(commit_ids):
            raise ValueError("batched commit metadata does not match the reachable Git ref universe")
        if scope==".":
            scope_commit_ids=commit_ids
        else:
            scope_commit_ids=git(root,"rev-list","--topo-order","--full-history","--exclude=refs/stash","--all","HEAD","--",scope).decode("ascii").splitlines()
        if not set(scope_commit_ids).issubset(set(commit_ids)):
            raise ValueError("scope history includes commits outside the accepted Git ref universe")
        scope_commit_set=set(scope_commit_ids)
        scope_commits=[row for row in commits if row["commit"] in scope_commit_set]
        versions:dict[str,list[dict[str,str]]]={}; blob_ids=set()
        # A scoped path state can change only in a commit that touches the
        # selected scope. Snapshot those commits only; metadata and Git object
        # pins still cover the complete reachable ref universe.
        for cid in scope_commit_ids:
            for item in tree(root,cid,scope):
                pin={"commit":cid,"path":item["path"],"mode":item["mode"],"git_object_id":item["oid"],"git_show_spec":f"{cid}:{item['path']}"}
                versions.setdefault(item["path"],[]).append(pin); blob_ids.add(item["oid"])
        expected_types={row["commit"]:"commit" for row in commits}
        expected_types.update({item["tree_object_id"]:"tree" for item in commits})
        expected_types.update({oid:"blob" for oid in blob_ids})
        object_ids=reachable_object_ids(root,refs)
        object_format=git(root,"rev-parse","--show-object-format").decode().strip()
        object_pins=pin_objects(root,object_ids,object_format,expected_types)
        blob_pins={oid:object_pins[oid] for oid in blob_ids}
        reachable_type_counts={kind:sum(1 for pin in object_pins.values() if pin["git_object_type"]==kind)
                               for kind in ("commit","tree","blob","tag")}
        head=git(root,"rev-parse","HEAD").decode().strip(); current={x["path"] for x in tree(root,head,scope)}
        historical=set(versions); disp, manifest_pin=dispositions(root,a.dispositions,scope,historical,current); records=[]
        for path in sorted(historical|current):
            present=path in current; item=disp.get(path); rows=versions.get(path,[])
            if item and item["status"]=="authorized-retired": status="authorized-retired"
            elif item: status=item["status"]
            elif present: status="present-path"
            else: status="unresolved-missing"
            records.append({"path":path,"scope_class":"active","status":status,"present_at_head":present,"historical_commit_count":len(rows),"historical_blob_ids":sorted({x["git_object_id"] for x in rows}),"versions":rows,"disposition":item})
        unresolved=[x for x in records if x["status"]=="unresolved-missing"]; rename_rows=renames(root,scope_commits,scope)
        report = {"schema_version": 3,"protocol":"GUP","evidence_kind":"repository-derived-rehydration-verification","scope":scope,"head":head,
                "scope_snapshot_policy":"path states are recorded for every reachable commit that changes the selected scope; metadata and object pins cover all reachable commits",
                "object_format":git(root,"rev-parse","--show-object-format").decode().strip(),"shallow_repository":shallow,"refs":refs,
                "reachable_commit_count":len(commits),"commits":commits,"scope_state_commit_count":len(scope_commit_ids),"scope_state_commits":scope_commit_ids,
                "historical_path_count":len(historical),"current_path_count":len(current),"authorized_retired_count":sum(1 for x in records if x["status"]=="authorized-retired"),
                "historical_path_version_count":sum(map(len,versions.values())),"rename_event_count":len(rename_rows),"rename_events":rename_rows,
                "git_object_count":len(object_pins),"reachable_object_count":len(object_pins),"reachable_object_type_counts":reachable_type_counts,
                "object_pins":object_pins,"blob_count":len(blob_pins),"blob_pins":blob_pins,"path_records":records,"dispositions_manifest":manifest_pin,"unresolved_missing_count":len(unresolved),
                "verification":{"all_git_object_ids_recomputed":all(x["git_object_id"]==x["git_object_id_recomputed"] for x in object_pins.values()),
                                "all_reachable_objects_pinned":set(object_pins)==set(object_ids),
                                "all_git_objects_sha256_pinned":all(len(x["sha256"])==64 for x in object_pins.values()),
                                "all_blob_git_ids_recomputed":all(x["git_object_id"]==x["git_object_id_recomputed"] for x in blob_pins.values()),
                                "all_blob_sha256_pinned":all(len(x["sha256"])==64 for x in blob_pins.values()),
                                "all_historical_path_versions_recorded":True,"shallow_history_blocks_strict":shallow}}
        encoded=(json.dumps(report,indent=2,sort_keys=True,ensure_ascii=True)+"\n").encode()
        if a.output: atomic_write(Path(a.output),encoded)
        else: sys.stdout.buffer.write(encoded)
        if a.strict and (unresolved or shallow or not report["verification"]["all_reachable_objects_pinned"]):
            print(f"GUP rehydration verification: FAIL — unresolved paths={len(unresolved)}, shallow_history={shallow}, all_reachable_objects_pinned={report['verification']['all_reachable_objects_pinned']}",file=sys.stderr); return 1
        print(f"GUP rehydration verification: {'FAIL' if shallow else 'PASS'} — commits={len(commits)}, paths={len(historical)}, blobs={len(blob_pins)}, unresolved={len(unresolved)}",file=sys.stderr)
        return 1 if shallow else 0
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError,json.JSONDecodeError) as exc:
        print(f"GUP rehydration verification failed: {exc}",file=sys.stderr); return 2
if __name__=="__main__": raise SystemExit(main())

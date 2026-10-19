#!/usr/bin/env python3
"""Capture deterministic Git and file-hash evidence; dirty state fails certification."""
from __future__ import annotations
import argparse, hashlib, json, os, subprocess, sys, tempfile
from pathlib import Path


def git(root: Path, *args: str, check: bool = True) -> bytes:
    result = subprocess.run(["git", "-C", str(root), *args], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, check=False, timeout=60)
    if check and result.returncode:
        raise RuntimeError(result.stderr.decode("utf-8", "replace").strip() or f"git {' '.join(args)} failed")
    return result.stdout


def atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temp = Path(name)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data); stream.flush(); os.fsync(stream.fileno())
        os.replace(temp, path)
        dfd = os.open(path.parent, os.O_RDONLY)
        try: os.fsync(dfd)
        finally: os.close(dfd)
    finally:
        temp.unlink(missing_ok=True)


def capture(root: Path) -> dict:
    root = root.resolve()
    head = git(root, "rev-parse", "HEAD").decode().strip()
    branch = git(root, "branch", "--show-current").decode().strip()
    status = git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all")
    status_items = [x.decode("utf-8", "surrogateescape") for x in status.split(b"\0") if x]
    tracked = [x for x in git(root, "ls-files", "-z").split(b"\0") if x]
    files = []
    for raw in tracked:
        rel = raw.decode("utf-8", "surrogateescape")
        path = root / rel
        data = path.read_bytes()  # Missing tracked files are a hard error.
        files.append({"path": rel, "sha256": hashlib.sha256(data).hexdigest(), "size_bytes": len(data)})
    refs = git(root, "for-each-ref", "--format=%(refname) %(objectname)").decode().splitlines()
    diff = git(root, "diff", "--binary", "HEAD", check=False)
    fingerprint_input = json.dumps(files, sort_keys=True, separators=(",", ":")).encode()
    return {
        "schema_version": 1, "protocol": "GUP", "head": head, "branch": branch,
        "worktree_clean": not bool(status_items), "status_entries": status_items,
        "tracked_file_count": len(files), "files": files, "refs": refs,
        "tracked_diff_sha256": hashlib.sha256(diff).hexdigest(),
        "file_manifest_sha256": hashlib.sha256(fingerprint_input).hexdigest(),
    }


def main() -> int:
    p=argparse.ArgumentParser(description=__doc__); p.add_argument("--root",default="."); p.add_argument("--output"); p.add_argument("--allow-dirty",action="store_true")
    a=p.parse_args(); root=Path(a.root)
    try:
        report=capture(root); encoded=(json.dumps(report,indent=2,sort_keys=True)+"\n").encode()
        if a.output: atomic_write(Path(a.output),encoded)
        else: sys.stdout.buffer.write(encoded)
        if not report["worktree_clean"] and not a.allow_dirty:
            print("GUP inventory: FAIL — worktree has staged, unstaged, or untracked changes",file=sys.stderr); return 1
        return 0
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        print(f"GUP inventory failed: {exc}",file=sys.stderr); return 2
if __name__=="__main__": raise SystemExit(main())

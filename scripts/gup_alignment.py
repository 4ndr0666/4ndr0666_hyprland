#!/usr/bin/env python3
"""Fail-closed bidirectional declaration/observation/provider/consumer reconciliation."""
from __future__ import annotations
import argparse, json, os, sys, tempfile
from pathlib import Path


def nonempty(value: object) -> bool: return isinstance(value, str) and bool(value.strip())
def atomic_write(path: Path, data: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temp = Path(name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(data); stream.flush(); os.fsync(stream.fileno())
        os.replace(temp, path)
        dfd=os.open(path.parent,os.O_RDONLY)
        try: os.fsync(dfd)
        finally: os.close(dfd)
    finally: temp.unlink(missing_ok=True)

def edge(item: dict, origin: str, errors: list[str], index: int) -> tuple | None:
    fields = ("id", "provider", "consumer")
    for field in fields:
        if not nonempty(item.get(field)): errors.append(f"{origin}[{index}] missing {field}")
    if origin == "declarations":
        for field in ("declaration_evidence", "provider_evidence", "consumer_evidence"):
            if not nonempty(item.get(field)): errors.append(f"declarations[{index}] missing {field}")
    else:
        if not nonempty(item.get("observation_evidence")): errors.append(f"observations[{index}] missing observation_evidence")
    if any(not nonempty(item.get(field)) for field in fields): return None
    return (item["id"], item["provider"], item["consumer"])

def main() -> int:
    p=argparse.ArgumentParser(description=__doc__); p.add_argument("input",help="alignment review JSON"); p.add_argument("--output"); a=p.parse_args()
    try:
        raw=json.loads(Path(a.input).read_text(encoding="utf-8")); errors=[]
        if not isinstance(raw,dict): raise ValueError("top-level value must be an object")
        declarations=raw.get("declarations"); observations=raw.get("observations")
        if not isinstance(declarations,list) or not isinstance(observations,list): raise ValueError("declarations and observations must be arrays")
        declared=[]; observed=[]
        for i,item in enumerate(declarations):
            if not isinstance(item,dict): errors.append(f"declarations[{i}] must be an object"); continue
            e=edge(item,"declarations",errors,i)
            if e: declared.append(e)
        for i,item in enumerate(observations):
            if not isinstance(item,dict): errors.append(f"observations[{i}] must be an object"); continue
            e=edge(item,"observations",errors,i)
            if e: observed.append(e)
        if len({e[0] for e in declared})!=len(declared): errors.append("duplicate declaration id")
        if len({e[0] for e in observed})!=len(observed): errors.append("duplicate observation id")
        if len(set(declared))!=len(declared): errors.append("duplicate declaration relationship")
        if len(set(observed))!=len(observed): errors.append("duplicate observed relationship")
        d=set(declared); o=set(observed)
        for e in sorted(d-o): errors.append(f"declared relationship has no observed consumer/provider edge: {e}")
        for e in sorted(o-d): errors.append(f"observed relationship is undeclared: {e}")
        result={"schema_version":1,"protocol":"GUP","gate":"bidirectional-alignment","status":"FAIL" if errors else "PASS","declaration_count":len(declared),"observation_count":len(observed),"errors":errors}
        encoded=json.dumps(result,indent=2,sort_keys=True)+"\n"
        if a.output: atomic_write(Path(a.output),encoded)
        else: print(encoded,end="")
        return 1 if errors else 0
    except (OSError,ValueError,json.JSONDecodeError) as exc:
        print(f"GUP alignment failed closed: {exc}",file=sys.stderr); return 2
if __name__=="__main__": raise SystemExit(main())

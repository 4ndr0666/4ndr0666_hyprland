#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/gup-history-continuity.XXXXXX")"
cleanup() { rm -rf -- "$TMP"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

git -C "$TMP" init -q
git -C "$TMP" config user.name "GUP Test"
git -C "$TMP" config user.email "gup-test@example.invalid"
mkdir -p "$TMP/config/hypr/UserConfigs" "$TMP/config/hypr/.bak" "$TMP/config/hypr/LEGACY_CODE/UserConfigs" "$TMP/config/hypr/UserScripts" "$TMP/config/hypr/scripts"
printf 'identical legacy behavior\n' > "$TMP/config/hypr/UserConfigs/Legacy.conf"
cp "$TMP/config/hypr/UserConfigs/Legacy.conf" "$TMP/config/hypr/UserConfigs/Duplicate.conf"
printf 'archived behavior\n' > "$TMP/config/hypr/.bak/ignored.conf"
printf 'authorized subtree candidate\n' > "$TMP/config/hypr/LEGACY_CODE/UserConfigs/old.conf"
printf 'backup script\n' > "$TMP/config/hypr/UserScripts/RainbowBorders.bak.sh"
printf 'generated temp file\n' > "$TMP/config/hypr/scripts/Refresh.sh.gup.tmp"
git -C "$TMP" add .
git -C "$TMP" commit -qm "historical baseline"
rm "$TMP/config/hypr/UserConfigs/Legacy.conf" "$TMP/config/hypr/UserConfigs/Duplicate.conf" "$TMP/config/hypr/.bak/ignored.conf" "$TMP/config/hypr/LEGACY_CODE/UserConfigs/old.conf" "$TMP/config/hypr/UserScripts/RainbowBorders.bak.sh" "$TMP/config/hypr/scripts/Refresh.sh.gup.tmp"
printf 'translated legacy behavior\n' > "$TMP/config/hypr/UserConfigs/Legacy.lua"
printf 'translated duplicate behavior\n' > "$TMP/config/hypr/UserConfigs/Duplicate.lua"
git -C "$TMP" add -A
git -C "$TMP" commit -qm "replace legacy paths"

python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" > "$TMP/report.json" ||
  fail "inventory command failed"
python3 - "$TMP/report.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
paths = {item["path"]: item for item in report["records"]}
legacy = "config/hypr/UserConfigs/Legacy.conf"
duplicate = "config/hypr/UserConfigs/Duplicate.conf"
archive = "config/hypr/.bak/ignored.conf"
old = "config/hypr/LEGACY_CODE/UserConfigs/old.conf"
backup_script = "config/hypr/UserScripts/RainbowBorders.bak.sh"
generated_temp = "config/hypr/scripts/Refresh.sh.gup.tmp"
assert legacy in paths, "deleted legacy path omitted"
assert duplicate in paths, "same-blob historical path omitted"
assert paths[legacy]["status"] == "unresolved-missing"
assert paths[duplicate]["status"] == "unresolved-missing"
assert paths[archive]["status"] == "unresolved-missing", "archive-named paths require explicit disposition"
assert paths[archive]["scope_class"] == "active"
assert paths[backup_script]["status"] == "unresolved-missing", "compound backup suffix is not retirement evidence"
assert paths[backup_script]["scope_class"] == "active"
assert paths[generated_temp]["status"] == "unresolved-missing", "generated-temp naming is not retirement evidence"
assert paths[generated_temp]["scope_class"] == "active"
assert paths[old]["status"] == "unresolved-missing"
assert report["unresolved_missing_count"] == 6
assert report["commit_count"] == 2
assert len(report["commits"]) == 2
assert "rename_events" in report
PY

if python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --strict > /dev/null 2>&1; then
  fail "strict mode accepted unresolved historical paths"
fi

cat > "$TMP/dispositions.json" <<'JSON'
{
  "config/hypr/UserConfigs/Legacy.conf": {
    "status": "translated",
    "target": "config/hypr/UserConfigs/Legacy.lua",
    "evidence": "synthetic test disposition"
  },
  "config/hypr/UserConfigs/Duplicate.conf": {
    "status": "preserved",
    "target": "config/hypr/UserConfigs/Duplicate.lua",
    "evidence": "synthetic test disposition"
  },
  "config/hypr/.bak/ignored.conf": {
    "status": "authorized-retired",
    "user_authorization": true,
    "evidence": "synthetic explicit retirement authorization for archived test fixture"
  },
  "config/hypr/UserScripts/RainbowBorders.bak.sh": {
    "status": "authorized-retired",
    "user_authorization": true,
    "evidence": "synthetic explicit retirement authorization for backup-named test fixture"
  },
  "config/hypr/scripts/Refresh.sh.gup.tmp": {
    "status": "authorized-retired",
    "user_authorization": true,
    "evidence": "synthetic explicit retirement authorization for generated-temp test fixture"
  },
  "authorized_subtrees": [
    {
      "path": "config/hypr/LEGACY_CODE",
      "status": "authorized-retired",
      "evidence": "synthetic explicit subtree retirement authorization",
      "user_authorization": true
    }
  ]
}
JSON
git -C "$TMP" add dispositions.json
git -C "$TMP" commit -qm "commit valid disposition test manifest"
python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --dispositions dispositions.json --strict > "$TMP/strict.json" ||
  fail "strict mode rejected valid evidence-backed dispositions"
# A dirty working-tree manifest must not override the manifest object committed at HEAD.
cp "$TMP/dispositions.json" "$TMP/dispositions.committed.json"
cat > "$TMP/dispositions.json" <<'JSON'
{"config/hypr/UserConfigs/Legacy.conf":{"status":"authorized-retired","user_authorization":true,"evidence":"uncommitted override must be ignored"}}
JSON
python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --dispositions dispositions.json --strict > "$TMP/head-manifest.json" ||
  fail "inventory used a modified working-tree manifest instead of committed HEAD"
python3 - "$TMP/head-manifest.json" "$TMP" <<'PY'
import json, subprocess, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
expected = subprocess.check_output(["git", "-C", sys.argv[2], "rev-parse", "HEAD:dispositions.json"], text=True).strip()
assert report["dispositions_manifest"]["git_object_id"] == expected
assert report["dispositions_manifest"]["source"] == "HEAD Git object"
assert len(report["dispositions_manifest"]["sha256"]) == 64
paths = {item["path"]: item for item in report["records"]}
assert paths["config/hypr/UserConfigs/Legacy.conf"]["status"] == "translated"
PY
mv "$TMP/dispositions.committed.json" "$TMP/dispositions.json"
python3 - "$TMP/strict.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["unresolved_missing_count"] == 0
assert report["authorized_retired_count"] == 4
paths = {item["path"]: item for item in report["records"]}
assert paths["config/hypr/UserConfigs/Legacy.conf"]["status"] == "translated"
assert paths["config/hypr/UserConfigs/Duplicate.conf"]["status"] == "preserved"
old = paths["config/hypr/LEGACY_CODE/UserConfigs/old.conf"]
assert old["status"] == "authorized-retired"
assert old["disposition"]["authorization_scope"] == "config/hypr/LEGACY_CODE"
assert paths["config/hypr/.bak/ignored.conf"]["status"] == "authorized-retired"
assert paths["config/hypr/UserScripts/RainbowBorders.bak.sh"]["status"] == "authorized-retired"
assert paths["config/hypr/scripts/Refresh.sh.gup.tmp"]["status"] == "authorized-retired"
assert report["dispositions_manifest"]["source"] == "HEAD Git object"
assert len(report["dispositions_manifest"]["git_object_id"]) in (40, 64)
assert len(report["dispositions_manifest"]["sha256"]) == 64
PY
mkdir -p "$TMP/config/hypr/LEGACY_CODE/current"
printf 'unexpected active path\n' > "$TMP/config/hypr/LEGACY_CODE/current/current.lua"
git -C "$TMP" add .
git -C "$TMP" commit -qm "add a current path beneath authorized retirement scope"
if python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --dispositions dispositions.json > /dev/null 2>&1; then
  fail "inventory accepted subtree retirement while current tracked paths remain beneath it"
fi

cat > "$TMP/invalid-dispositions.json" <<'JSON'
{
  "config/hypr/UserConfigs/Legacy.conf": {
    "status": "translated",
    "target": "config/hypr/UserConfigs/not-present.lua",
    "evidence": "invalid target"
  }
}
JSON
git -C "$TMP" add invalid-dispositions.json
git -C "$TMP" commit -qm "commit invalid target test manifest"
if python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --dispositions invalid-dispositions.json > /dev/null 2>&1; then
  fail "inventory accepted a disposition whose target is not in candidate HEAD"
fi

cat > "$TMP/invalid-subtree.json" <<'JSON'
{
  "authorized_subtrees": [
    {
      "path": "config/hypr",
      "status": "authorized-retired",
      "evidence": "overbroad scope",
      "user_authorization": true
    }
  ]
}
JSON
git -C "$TMP" add invalid-subtree.json
git -C "$TMP" commit -qm "commit invalid subtree test manifest"
if python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --dispositions invalid-subtree.json > /dev/null 2>&1; then
  fail "inventory accepted a subtree equal to the entire requested scope"
fi

if python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --scope ../ > /dev/null 2>&1; then
  fail "inventory accepted an unsafe path scope"
fi

cat > "$TMP/empty-subtree.json" <<'JSON'
{
  "authorized_subtrees": [
    {
      "path": "config/hypr/does-not-exist",
      "status": "authorized-retired",
      "evidence": "no historical paths should be silently accepted",
      "user_authorization": true
    }
  ]
}
JSON
git -C "$TMP" add empty-subtree.json
git -C "$TMP" commit -qm "commit empty subtree test manifest"
if python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --dispositions empty-subtree.json > /dev/null 2>&1; then
  fail "inventory accepted retirement authorization for a subtree with no historical paths"
fi

cat > "$TMP/dot-segment-dispositions.json" <<'JSON'
{
  "config/hypr/./UserConfigs/Legacy.conf": {
    "status": "authorized-retired",
    "user_authorization": true,
    "evidence": "dot-segment path must be rejected"
  }
}
JSON
git -C "$TMP" add dot-segment-dispositions.json
git -C "$TMP" commit -qm "commit unsafe dot-segment manifest"
if python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --dispositions dot-segment-dispositions.json > /dev/null 2>&1; then
  fail "inventory accepted a disposition path containing a dot segment"
fi

printf '[PASS] complete path inventory, shared blob paths, explicit retirement authorization, strict unresolved-path gate, and invalid-input rejection.\n'
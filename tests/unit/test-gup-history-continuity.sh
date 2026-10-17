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
mkdir -p "$TMP/config/hypr/UserConfigs" "$TMP/config/hypr/.bak"
printf 'identical legacy behavior\n' > "$TMP/config/hypr/UserConfigs/Legacy.conf"
cp "$TMP/config/hypr/UserConfigs/Legacy.conf" "$TMP/config/hypr/UserConfigs/Duplicate.conf"
printf 'archived behavior\n' > "$TMP/config/hypr/.bak/ignored.conf"
git -C "$TMP" add .
git -C "$TMP" commit -qm "historical baseline"
rm "$TMP/config/hypr/UserConfigs/Legacy.conf" "$TMP/config/hypr/UserConfigs/Duplicate.conf" "$TMP/config/hypr/.bak/ignored.conf"
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
assert legacy in paths, "deleted legacy path omitted"
assert duplicate in paths, "same-blob historical path omitted"
assert paths[legacy]["status"] == "unresolved-missing"
assert paths[duplicate]["status"] == "unresolved-missing"
assert paths[archive]["status"] == "archive-path-missing", "archive evidence must remain visible"
assert paths[archive]["scope_class"] == "archive"
assert report["unresolved_missing_count"] == 2
assert report["archive_path_count"] == 1
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
  }
}
JSON
python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --dispositions dispositions.json --strict > "$TMP/strict.json" ||
  fail "strict mode rejected valid evidence-backed dispositions"
python3 - "$TMP/strict.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["unresolved_missing_count"] == 0
paths = {item["path"]: item for item in report["records"]}
assert paths["config/hypr/UserConfigs/Legacy.conf"]["status"] == "translated"
assert paths["config/hypr/UserConfigs/Duplicate.conf"]["status"] == "preserved"
PY

cat > "$TMP/invalid-dispositions.json" <<'JSON'
{
  "config/hypr/UserConfigs/Legacy.conf": {
    "status": "translated",
    "target": "config/hypr/UserConfigs/not-present.lua",
    "evidence": "invalid target"
  }
}
JSON
if python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --dispositions invalid-dispositions.json > /dev/null 2>&1; then
  fail "inventory accepted a disposition whose target is not in candidate HEAD"
fi

if python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --scope ../ > /dev/null 2>&1; then
  fail "inventory accepted an unsafe path scope"
fi

printf '[PASS] complete path inventory, shared blob paths, visible archives, strict gate, dispositions, and invalid-input rejection.\n'

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
printf 'old behavior\n' > "$TMP/config/hypr/UserConfigs/Legacy.conf"
printf 'backup\n' > "$TMP/config/hypr/.bak/ignored.conf"
git -C "$TMP" add .
git -C "$TMP" commit -qm "historical baseline"
rm "$TMP/config/hypr/UserConfigs/Legacy.conf"
printf 'translated behavior\n' > "$TMP/config/hypr/UserConfigs/Legacy.lua"
git -C "$TMP" add -A
git -C "$TMP" commit -qm "replace legacy path"
python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" > "$TMP/report.json" ||
  fail "inventory command failed"
python3 - "$TMP/report.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
paths = {item["path"]: item for item in report["records"]}
assert "config/hypr/UserConfigs/Legacy.conf" in paths
assert paths["config/hypr/UserConfigs/Legacy.conf"]["status"] == "unresolved-missing"
assert "config/hypr/.bak/ignored.conf" not in paths
assert report["unresolved_missing_count"] == 1
PY
if python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --strict > /dev/null 2>&1; then
  fail "strict mode accepted unresolved historical path"
fi
cat > "$TMP/dispositions.json" <<'JSON'
{
  "config/hypr/UserConfigs/Legacy.conf": {
    "status": "translated",
    "target": "config/hypr/UserConfigs/Legacy.lua",
    "evidence": "synthetic test disposition"
  }
}
JSON
python3 "$ROOT/scripts/gup-history-continuity.py" --root "$TMP" --dispositions dispositions.json --strict > "$TMP/strict.json" ||
  fail "strict mode rejected an evidence-backed disposition"
python3 - "$TMP/strict.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["unresolved_missing_count"] == 0
PY
printf '[PASS] historical inventory, backup exclusion, strict failure, and explicit disposition are validated.\n'

#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

required_files=(
  "golden_unit_hash.py"
  "scripts/gup_init.py"
  "scripts/gup_inventory.py"
  "scripts/gup_history_continuity.py"
  "scripts/gup_alignment.py"
  "scripts/gup_validate.py"
  "schemas/gup-alignment.schema.json"
  "schemas/gup-evidence.schema.json"
  "tests/test_gup_tools.py"
)

for rel in "${required_files[@]}"; do
  [[ -f "$ROOT/$rel" ]] || fail "Missing GUP v7.0.1 toolchain file: $rel"
done

python3 -B "$ROOT/golden_unit_hash.py" --selftest >/dev/null || fail "golden_unit_hash.py --selftest failed"
python3 -B -m unittest discover -s "$ROOT/tests" -p "test_gup_tools.py" || fail "tests/test_gup_tools.py failed"

printf '[PASS] GUP v7.0.1 executable toolchain, schemas, and synthetic Git test suite verified.\n'

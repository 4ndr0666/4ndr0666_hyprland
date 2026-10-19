#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PARSER="$ROOT_DIR/config/hypr/scripts/keybinds_parser.py"
KEYBINDS="$ROOT_DIR/config/hypr/configs/Keybinds.lua"
USER_KEYBINDS="$ROOT_DIR/config/hypr/UserConfigs/UserKeybinds.lua"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -f "$PARSER" ]] || fail "keybind parser is missing"
[[ -f "$KEYBINDS" ]] || fail "authoritative Lua keybind source is missing"
[[ -f "$USER_KEYBINDS" ]] || fail "user Lua keybind source is missing"

python3 -B -c "import py_compile, sys, tempfile; f = tempfile.NamedTemporaryFile(delete=True); f.close(); py_compile.compile(sys.argv[1], cfile=f.name, doraise=True)" "$PARSER" || fail "keybind parser has invalid Python syntax"
output="$(python3 -B "$PARSER" "$KEYBINDS" "$USER_KEYBINDS")" || fail "Lua keybind parser rejected authoritative source"
[[ -n "$output" ]] || fail "Lua keybind parser produced no output"
grep -Fq 'SUPER+D — app launcher' <<<"$output" || fail "Lua keybind app launcher was not represented"
grep -Fq 'SUPER+SHIFT+K — search keybinds' <<<"$output" || fail "Lua keybind search entry was not represented"
grep -Fq 'SUPER+W — select wallpaper' <<<"$output" || fail "Lua keybind wallpaper entry was not represented"
grep -Fq 'SUPER+ALT+SPACE — Float all windows' <<<"$output" || fail "Multiline SUPER+ALT+SPACE keybind was not represented"
grep -Fq 'SUPER+M — adjust current layout ratio' <<<"$output" || fail "Multiline SUPER+M user keybind was not represented"
grep -Fq 'SUPER+code:10 — switch to workspace 1' <<<"$output" || fail "Loop-expanded SUPER+code:10 focus bind was not represented"
grep -Fq 'SUPER+SHIFT+code:19 — move to workspace 0' <<<"$output" || fail "Loop-expanded SUPER+SHIFT+code:19 move bind was not represented"
! grep -Fq 'code:code' <<<"$output" || fail "Unexpanded loop variable code:code leaked into parser output"

json_out="$(python3 -B "$PARSER" --path "$KEYBINDS")" || fail "keybind parser --path JSON mode failed"
python3 -c '
import json, sys
payload = json.loads(sys.argv[1])
assert isinstance(payload, dict) and isinstance(payload.get("children"), list) and len(payload["children"]) > 40
assert any(item.get("key") == "SPACE" and "ALT" in item.get("mods", []) and item.get("comment") == "Float all windows" for item in payload["children"])
' "$json_out" || fail "keybind parser --path JSON output failed schema/content verification"

printf 'PASS: keybind parser consumes authoritative Lua bindings (single-line, multiline, loop, and JSON modes)\n'

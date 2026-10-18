#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PARSER="$ROOT_DIR/config/hypr/scripts/keybinds_parser.py"
KEYBINDS="$ROOT_DIR/config/hypr/configs/Keybinds.lua"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -f "$PARSER" ]] || fail "keybind parser is missing"
[[ -f "$KEYBINDS" ]] || fail "authoritative Lua keybind source is missing"

python3 -B -c "import py_compile, sys, tempfile; f = tempfile.NamedTemporaryFile(delete=True); f.close(); py_compile.compile(sys.argv[1], cfile=f.name, doraise=True)" "$PARSER" || fail "keybind parser has invalid Python syntax"
output="$(python3 -B "$PARSER" "$KEYBINDS")" || fail "Lua keybind parser rejected authoritative source"
[[ -n "$output" ]] || fail "Lua keybind parser produced no output"
grep -Fq 'SUPER+D — app launcher' <<<"$output" || fail "Lua keybind app launcher was not represented"
grep -Fq 'SUPER+SHIFT+K — search keybinds' <<<"$output" || fail "Lua keybind search entry was not represented"
grep -Fq 'SUPER+W — select wallpaper' <<<"$output" || fail "Lua keybind wallpaper entry was not represented"

printf 'PASS: keybind parser consumes authoritative Lua bindings\n'

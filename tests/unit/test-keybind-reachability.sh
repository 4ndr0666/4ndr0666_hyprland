#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
KEYBINDS="$ROOT_DIR/config/hypr/configs/Keybinds.lua"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -f "$KEYBINDS" ]] || fail "authoritative Lua keybind source is missing"

while IFS= read -r ref; do
    case "$ref" in
        scriptsDir/*)
            target="$ROOT_DIR/config/hypr/scripts/${ref#scriptsDir/}"
            ;;
        UserScripts/*)
            target="$ROOT_DIR/config/hypr/UserScripts/${ref#UserScripts/}"
            ;;
        *)
            continue
            ;;
    esac
    [[ -f "$target" ]] || fail "keybind target is missing: $ref"
done < <(sed -nE 's/.*(scriptsDir|UserScripts) \.\. "\/([^"]+)".*/\1\/\2/p' "$KEYBINDS")

printf 'PASS: all repository-backed Lua keybind targets resolve to files\n'

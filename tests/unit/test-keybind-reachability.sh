#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
KEYBINDS="$ROOT_DIR/config/hypr/configs/Keybinds.lua"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -f "$KEYBINDS" ]] || fail "authoritative Lua keybind source is missing"

found=0
while IFS='|' read -r owner relative; do
    [[ -n "$owner" && -n "$relative" ]] || continue
    found=1
    case "$owner" in
        scriptsDir) target="$ROOT_DIR/config/hypr/scripts/$relative" ;;
        UserScripts) target="$ROOT_DIR/config/hypr/UserScripts/$relative" ;;
        *) fail "unknown keybind path authority: $owner" ;;
    esac
    [[ -f "$target" ]] || fail "keybind target is missing: $owner/$relative"
done < <(sed -nE 's/.*(scriptsDir|UserScripts)[[:space:]]+\.\.[[:space:]]+"\/([^"[:space:]]+).*/\1|\2/p' "$KEYBINDS")

((found == 1)) || fail "no repository-backed keybind targets were discovered"
printf 'PASS: all repository-backed Lua keybind targets resolve to files\n'

#!/usr/bin/env bash
# Shared, atomic mutations for the authoritative Hyprland Lua configuration.

set -Eeuo pipefail

append_lua_module_line() (
  local file="$1"
  local marker="$2"
  local line="$3"
  local tmp=""

  [[ -f "$file" ]] || {
    printf '[ERROR] Required Lua module is missing: %s\n' "$file" >&2
    return 1
  }
  grep -Fq -- "$marker" "$file" && return 0

  tmp="$(mktemp --tmpdir="$(dirname -- "$file")" ".$(basename -- "$file").XXXXXX")" || return 1
  trap 'if [[ -n "$tmp" ]]; then rm -f -- "$tmp"; fi' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  cat -- "$file" >"$tmp" || return 1
  printf '\n%s\n' "$line" >>"$tmp" || return 1
  chmod --reference="$file" "$tmp" || return 1
  mv -- "$tmp" "$file" || return 1
  tmp=""
)

append_startup_command() {
  local command="$1"
  [[ "$command" =~ ^[A-Za-z0-9_./-]+$ ]] || {
    printf '[ERROR] Refusing unsafe startup command token: %s\n' "$command" >&2
    return 2
  }
  append_lua_module_line \
    "config/hypr/configs/Startup_Apps.lua" \
    "hl.exec_cmd(\"$command\")" \
    "hl.on(\"hyprland.start\", function()"$'\n'"    hl.exec_cmd(\"$command\")"$'\n'"end)"
}

append_startup_expression() {
  local marker="$1"
  local expression="$2"
  append_lua_module_line \
    "config/hypr/configs/Startup_Apps.lua" \
    "$marker" \
    "hl.on(\"hyprland.start\", function()"$'\n'"    hl.exec_cmd($expression)"$'\n'"end)"
}

append_lua_env() {
  local key="$1"
  local value="$2"
  [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ && "$value" =~ ^[A-Za-z0-9_./-]+$ ]] || {
    printf '[ERROR] Refusing invalid Lua environment assignment: %s=%s\n' "$key" "$value" >&2
    return 2
  }
  append_lua_module_line \
    "config/hypr/configs/ENVariables.lua" \
    "hl.env(\"$key\", \"$value\")" \
    "hl.env(\"$key\", \"$value\")"
}

set_lua_assignment() (
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp=""
  local matches

  [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || {
    printf '[ERROR] Refusing invalid Lua assignment key: %s\n' "$key" >&2
    return 2
  }
  [[ "$value" =~ ^(\"[A-Za-z0-9_,+ -]+\"|[0-9]+([.][0-9]+)?)$ ]] || {
    printf '[ERROR] Refusing invalid Lua assignment value for %s.\n' "$key" >&2
    return 2
  }
  [[ -f "$file" ]] || {
    printf '[ERROR] Required Lua module is missing: %s\n' "$file" >&2
    return 1
  }
  matches="$(grep -Ec "^[[:space:]]*$key[[:space:]]*=" "$file")" || return 1
  [[ "$matches" -eq 1 ]] || {
    printf '[ERROR] Expected exactly one %s assignment in %s; found %s.\n' "$key" "$file" "$matches" >&2
    return 1
  }

  tmp="$(mktemp --tmpdir="$(dirname -- "$file")" ".$(basename -- "$file").XXXXXX")" || return 1
  trap 'if [[ -n "$tmp" ]]; then rm -f -- "$tmp"; fi' EXIT HUP INT TERM
  awk -v key="$key" -v value="$value" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/=.*/, "= " value ",")
      found++
    }
    { print }
    END { if (found != 1) exit 42 }
  ' "$file" >"$tmp" || return 1
  chmod --reference="$file" "$tmp" || return 1
  mv -- "$tmp" "$file" || return 1
  tmp=""
)

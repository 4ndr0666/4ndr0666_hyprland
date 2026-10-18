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

  local grep_status
  if grep -Fq -- "$marker" "$file"; then
    return 0
  else
    grep_status=$?
  fi
  if ((grep_status != 1)); then
    printf '[ERROR] Failed to inspect Lua module for marker: %s\n' "$file" >&2
    return "$grep_status"
  fi

  tmp="$(mktemp --tmpdir="$(dirname -- "$file")" ".$(basename -- "$file").XXXXXX")" || return 1
  cleanup_lua_mutation_temp() {
    local status=$?
    if [[ -n "$tmp" ]] && ! rm -f -- "$tmp"; then
      printf '[ERROR] Failed to remove Lua mutation temporary file: %s\n' "$tmp" >&2
      [[ "$status" -ne 0 ]] || status=1
    fi
    exit "$status"
  }
  trap cleanup_lua_mutation_temp EXIT
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
  matches="$(grep -Ec "^[[:space:]]*${key}[[:space:]]*=" "$file")" || return 1
  [[ "$matches" -eq 1 ]] || {
    printf '[ERROR] Expected exactly one %s assignment in %s; found %s.\n' "$key" "$file" "$matches" >&2
    return 1
  }

  tmp="$(mktemp --tmpdir="$(dirname -- "$file")" ".$(basename -- "$file").XXXXXX")" || return 1
  cleanup_lua_assignment_temp() {
    local status=$?
    if [[ -n "$tmp" ]] && ! rm -f -- "$tmp"; then
      printf '[ERROR] Failed to remove Lua assignment temporary file: %s\n' "$tmp" >&2
      [[ "$status" -ne 0 ]] || status=1
    fi
    exit "$status"
  }
  trap cleanup_lua_assignment_temp EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
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

translate_legacy_userconfigs_to_lua() {
  local backup_dir="$1"
  local target_user_dir="$2"
  local log="${3:-/dev/null}"

  [[ -d "$backup_dir" && -d "$target_user_dir" ]] || return 0

  # 1. Translate legacy Startup_Apps.conf exec-once entries into UserConfigs/Startup_Apps.lua
  local old_startup="$backup_dir/Startup_Apps.conf"
  local lua_startup="$target_user_dir/Startup_Apps.lua"
  if [[ -f "$old_startup" && -f "$lua_startup" ]]; then
    local overlay_tmp disable_tmp empty_base
    overlay_tmp="$(mktemp)"
    disable_tmp="$(mktemp)"
    empty_base="$(mktemp)"
    if declare -F compose_overlay_from_backup >/dev/null 2>&1; then
      compose_overlay_from_backup startup "$empty_base" "$old_startup" "$overlay_tmp" "$disable_tmp" || true
    else
      awk '/^[[:space:]]*exec-once[[:space:]]*=/ { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }' "$old_startup" | sort -u >"$overlay_tmp" || true
    fi
    while IFS= read -r raw_line; do
      local cmd="${raw_line#*=}"
      cmd="$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [[ -n "$cmd" ]] || continue
      case "$cmd" in
        *KeybindsLayoutInit.sh*|*4ndr0init.sh*|*Dropterminal.sh*|*nm-applet*|*nm-tray*|*hypridle*|*cliphist*|*mem-police*)
          continue
          ;;
      esac
      local escaped_cmd
      escaped_cmd="$(printf '%s' "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')"
      append_lua_module_line "$lua_startup" "hl.exec_cmd(\"$escaped_cmd\")" \
        "hl.on(\"hyprland.start\", function()"$'\n'"    hl.exec_cmd(\"$escaped_cmd\")"$'\n'"end)"
    done <"$overlay_tmp"
    rm -f -- "$overlay_tmp" "$disable_tmp" "$empty_base"
    printf '%s\n' "[INFO] Translated legacy Startup_Apps.conf entries into $lua_startup." | tee -a "$log"
  fi

  # 2. Translate legacy ENVariables.conf env entries into UserConfigs/ENVariables.lua
  local old_env="$backup_dir/ENVariables.conf"
  local lua_env="$target_user_dir/ENVariables.lua"
  if [[ -f "$old_env" && -f "$lua_env" ]]; then
    while IFS= read -r line; do
      local rhs="${line#*=}"
      local key="${rhs%%,*}"
      local val="${rhs#*,}"
      key="$(printf '%s' "$key" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      val="$(printf '%s' "$val" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      if [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ && -n "$val" ]]; then
        local escaped_val
        escaped_val="$(printf '%s' "$val" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        append_lua_module_line "$lua_env" "hl.env(\"$key\", \"$escaped_val\")" "hl.env(\"$key\", \"$escaped_val\")"
      fi
    done < <(awk '/^[[:space:]]*envd?[[:space:]]*=/ && $0 ~ /,/ { print }' "$old_env")
    printf '%s\n' "[INFO] Translated legacy ENVariables.conf entries into $lua_env." | tee -a "$log"
  fi
}

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

  local had_return=0
  if awk '/^[[:space:]]*return[[:space:]]+true[[:space:]]*$/ { found=1 } END { exit(found ? 0 : 1) }' "$file"; then
    had_return=1
  fi
  if ((had_return)); then
    awk '!/^[[:space:]]*return[[:space:]]+true[[:space:]]*$/ { print }' "$file" >"$tmp" || return 1
    printf '\n%s\n\nreturn true\n' "$line" >>"$tmp" || return 1
  else
    cat -- "$file" >"$tmp" || return 1
    printf '\n%s\n' "$line" >>"$tmp" || return 1
  fi
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

translate_legacy_windowrule_line_to_lua() {
  local raw_line="$1"
  local lhs="${raw_line%%=*}"
  local rhs="${raw_line#*=}"
  lhs="$(printf '%s' "$lhs" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  rhs="$(printf '%s' "$rhs" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [[ -n "$rhs" ]] || return 1

  if [[ "$lhs" == "layerrule" ]]; then
    local effect="${rhs%%,*}"
    local ns="${rhs#*,}"
    effect="$(printf '%s' "$effect" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    ns="$(printf '%s' "$ns" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [[ -n "$effect" && -n "$ns" && "$ns" != "$rhs" ]] || return 1
    local escaped_ns
    escaped_ns="$(printf '%s' "$ns" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    local prop=""
    case "$effect" in
      blur) prop="blur = true" ;;
      ignorezero) prop="ignore_zero = true" ;;
      ignorealpha[[:space:]]*)
        local alpha="${effect#ignorealpha}"
        alpha="$(printf '%s' "$alpha" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        [[ "$alpha" =~ ^[0-9]+([.][0-9]+)?$ ]] || alpha="0.5"
        prop="ignore_alpha = $alpha"
        ;;
      xray[[:space:]]*)
        local xray_val="${effect#xray}"
        xray_val="$(printf '%s' "$xray_val" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        [[ "$xray_val" =~ ^[0-9]+$ ]] || xray_val="1"
        prop="xray = $xray_val"
        ;;
      noanim) prop="no_anim = true" ;;
      *)
        local escaped_eff
        escaped_eff="$(printf '%s' "$effect" | sed -E 's/[^a-zA-Z0-9_]/_/g')"
        prop="${escaped_eff} = true"
        ;;
    esac
    printf 'hl.layer_rule({ match = { namespace = "%s" }, %s })\n' "$escaped_ns" "$prop"
    return 0
  fi

  local -a tokens=()
  local token
  IFS=',' read -r -a tokens <<<"$rhs"
  ((${#tokens[@]} >= 2)) || return 1

  local -a match_parts=()
  local -a effect_parts=()
  local idx=0
  local total="${#tokens[@]}"
  for token in "${tokens[@]}"; do
    idx=$((idx + 1))
    token="$(printf '%s' "$token" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [[ -n "$token" ]] || continue
    case "$token" in
      class:*)
        local val="${token#class:}"
        val="$(printf '%s' "$val" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        match_parts+=("class = \"$val\"")
        ;;
      title:*)
        local val="${token#title:}"
        val="$(printf '%s' "$val" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        match_parts+=("title = \"$val\"")
        ;;
      initialClass:*|initialclass:*)
        local val="${token#*:}"
        val="$(printf '%s' "$val" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        match_parts+=("initial_class = \"$val\"")
        ;;
      initialTitle:*|initialtitle:*)
        local val="${token#*:}"
        val="$(printf '%s' "$val" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        match_parts+=("initial_title = \"$val\"")
        ;;
      tag:*)
        local val="${token#tag:}"
        val="$(printf '%s' "$val" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        match_parts+=("tag = \"$val\"")
        ;;
      xwayland:1|xwayland:true) match_parts+=("xwayland = true") ;;
      xwayland:0|xwayland:false) match_parts+=("xwayland = false") ;;
      floating:1|floating:true) match_parts+=("float = true") ;;
      floating:0|floating:false) match_parts+=("float = false") ;;
      fullscreen:1|fullscreen:true) match_parts+=("fullscreen = true") ;;
      fullscreen:0|fullscreen:false) match_parts+=("fullscreen = false") ;;
      pinned:1|pinned:true) match_parts+=("pin = true") ;;
      pinned:0|pinned:false) match_parts+=("pin = false") ;;
      *)
        if ((idx == total && ${#match_parts[@]} == 0)); then
          local val
          val="$(printf '%s' "$token" | sed 's/\\/\\\\/g; s/"/\\"/g')"
          match_parts+=("class = \"$val\"")
        else
          local eff_name="${token%%[[:space:]]*}"
          local eff_arg="${token#"$eff_name"}"
          eff_arg="$(printf '%s' "$eff_arg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
          local escaped_arg
          escaped_arg="$(printf '%s' "$eff_arg" | sed 's/\\/\\\\/g; s/"/\\"/g')"
          case "$eff_name" in
            float) effect_parts+=("float = true") ;;
            tile) effect_parts+=("tile = true") ;;
            center) effect_parts+=("center = true") ;;
            pin) effect_parts+=("pin = true") ;;
            fullscreen) effect_parts+=("fullscreen = true") ;;
            noblur|noblar) effect_parts+=("no_blur = true") ;;
            nofocus) effect_parts+=("no_focus = true") ;;
            noinitialfocus) effect_parts+=("no_initial_focus = true") ;;
            noshadow) effect_parts+=("no_shadow = true") ;;
            noborder) effect_parts+=("no_border = true") ;;
            opaque) effect_parts+=("opaque = true") ;;
            keepaspectratio) effect_parts+=("keep_aspect_ratio = true") ;;
            stayfocused) effect_parts+=("stay_focused = true") ;;
            opacity) effect_parts+=("opacity = \"$escaped_arg\"") ;;
            size) effect_parts+=("size = \"$escaped_arg\"") ;;
            move) effect_parts+=("move = \"$escaped_arg\"") ;;
            workspace) effect_parts+=("workspace = \"$escaped_arg\"") ;;
            tag) effect_parts+=("tag = \"$escaped_arg\"") ;;
            idleinhibit) effect_parts+=("idle_inhibit = \"$escaped_arg\"") ;;
            animation) effect_parts+=("animation = \"$escaped_arg\"") ;;
            *)
              local norm_eff
              norm_eff="$(printf '%s' "$eff_name" | sed -E 's/[^a-zA-Z0-9_]/_/g')"
              if [[ -n "$escaped_arg" ]]; then
                effect_parts+=("${norm_eff} = \"$escaped_arg\"")
              else
                effect_parts+=("${norm_eff} = true")
              fi
              ;;
          esac
        fi
        ;;
    esac
  done

  ((${#match_parts[@]} > 0 && ${#effect_parts[@]} > 0)) || return 1
  local match_joined effect_joined
  printf -v match_joined '%s, ' "${match_parts[@]}"
  match_joined="${match_joined%, }"
  printf -v effect_joined '%s, ' "${effect_parts[@]}"
  effect_joined="${effect_joined%, }"
  printf 'hl.window_rule({ match = { %s }, %s })\n' "$match_joined" "$effect_joined"
}

translate_legacy_keybind_line_to_lua() {
  local raw_line="$1"
  local lhs="${raw_line%%=*}"
  local rhs="${raw_line#*=}"
  lhs="$(printf '%s' "$lhs" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  rhs="$(printf '%s' "$rhs" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [[ "$lhs" =~ ^bind[elmnr]*$ && -n "$rhs" ]] || return 1

  local mod_part key_part disp_part arg_part=""
  IFS=',' read -r mod_part key_part disp_part arg_part <<<"$rhs"
  mod_part="$(printf '%s' "${mod_part:-}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/\$mainMod/SUPER/g')"
  key_part="$(printf '%s' "${key_part:-}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  disp_part="$(printf '%s' "${disp_part:-}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  arg_part="$(printf '%s' "${arg_part:-}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [[ -n "$key_part" && -n "$disp_part" ]] || return 1

  local chord=""
  if [[ -n "$mod_part" ]]; then
    local norm_mods
    norm_mods="$(printf '%s' "$mod_part" | sed -E 's/[[:space:]_+]+/ + /g; s/^ \+ //; s/ \+ $//')"
    chord="${norm_mods} + ${key_part}"
  else
    chord="$key_part"
  fi
  local escaped_chord
  escaped_chord="$(printf '%s' "$chord" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  local expanded_arg="$arg_part"
  expanded_arg="${expanded_arg//\$scriptsDir/\$HOME/.config/hypr/scripts}"
  expanded_arg="${expanded_arg//\$UserScripts/\$HOME/.config/hypr/UserScripts}"
  expanded_arg="${expanded_arg//\$term/kitty}"
  expanded_arg="${expanded_arg//\$files/thunar}"
  local escaped_arg
  escaped_arg="$(printf '%s' "$expanded_arg" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  local action_expr=""
  case "$disp_part" in
    exec)
      action_expr="hl.dsp.exec_cmd(\"$escaped_arg\")"
      ;;
    workspace)
      if [[ "$arg_part" =~ ^[0-9]+$ ]]; then
        action_expr="hl.dsp.focus({ workspace = $arg_part })"
      else
        action_expr="hl.dsp.focus({ workspace = \"$escaped_arg\" })"
      fi
      ;;
    movetoworkspace)
      if [[ "$arg_part" =~ ^[0-9]+$ ]]; then
        action_expr="hl.dsp.move_to_workspace({ workspace = $arg_part, follow = true })"
      else
        action_expr="hl.dsp.move_to_workspace({ workspace = \"$escaped_arg\", follow = true })"
      fi
      ;;
    movetoworkspacesilent)
      if [[ "$arg_part" =~ ^[0-9]+$ ]]; then
        action_expr="hl.dsp.move_to_workspace({ workspace = $arg_part, follow = false })"
      else
        action_expr="hl.dsp.move_to_workspace({ workspace = \"$escaped_arg\", follow = false })"
      fi
      ;;
    killactive)
      action_expr="hl.dsp.window.close()"
      ;;
    fullscreen)
      action_expr="hl.dsp.window.fullscreen()"
      ;;
    togglefloating)
      action_expr="hl.dsp.window.float({ action = \"toggle\" })"
      ;;
    pseudo)
      action_expr="hl.dsp.layout(\"pseudo\")"
      ;;
    togglesplit)
      action_expr="hl.dsp.layout(\"togglesplit\")"
      ;;
    *)
      if [[ -n "$escaped_arg" ]]; then
        action_expr="hl.dsp.layout(\"$disp_part $escaped_arg\")"
      else
        action_expr="hl.dsp.layout(\"$disp_part\")"
      fi
      ;;
  esac

  local -a opts=("description = \"migrated: $escaped_chord\"")
  [[ "$lhs" == *e* ]] && opts+=("repeat_press = true")
  [[ "$lhs" == *l* ]] && opts+=("locked = true")
  [[ "$lhs" == *m* ]] && opts+=("mouse = true")
  [[ "$lhs" == *r* ]] && opts+=("release = true")
  local opts_joined
  printf -v opts_joined '%s, ' "${opts[@]}"
  opts_joined="${opts_joined%, }"
  printf 'hl.bind("%s", %s, { %s })\n' "$escaped_chord" "$action_expr" "$opts_joined"
}

translate_legacy_monitors_and_workspaces_to_lua() {
  local backup_hypr_dir="$1"
  local target_hypr_dir="$2"
  local log="${3:-/dev/null}"

  [[ -d "$backup_hypr_dir" && -d "$target_hypr_dir" ]] || return 0

  local old_monitors="$backup_hypr_dir/monitors.conf"
  local lua_monitors="$target_hypr_dir/monitors.lua"
  if [[ -f "$old_monitors" && ! -f "$backup_hypr_dir/monitors.lua" && -f "$lua_monitors" ]]; then
    while IFS= read -r line; do
      local rhs="${line#*=}"
      local mon_name mon_mode mon_pos mon_scale
      IFS=',' read -r mon_name mon_mode mon_pos mon_scale <<<"$rhs"
      mon_name="$(printf '%s' "${mon_name:-}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      mon_mode="$(printf '%s' "${mon_mode:-preferred}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      mon_pos="$(printf '%s' "${mon_pos:-auto}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      mon_scale="$(printf '%s' "${mon_scale:-1}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [[ -n "$mon_name" && "$mon_name" != desc:* ]] || continue
      [[ "$mon_scale" =~ ^[0-9]+([.][0-9]+)?$ ]] || mon_scale="1"
      append_lua_module_line \
        "$lua_monitors" \
        "output = \"$mon_name\"" \
        "hl.monitor({ output = \"$mon_name\", mode = \"$mon_mode\", position = \"$mon_pos\", scale = $mon_scale })"
    done < <(awk '/^[[:space:]]*monitor[[:space:]]*=/ { print }' "$old_monitors")
    printf '%s\n' "[INFO] Translated legacy monitors.conf entries into $lua_monitors." | tee -a "$log"
  fi

  local old_workspaces="$backup_hypr_dir/workspaces.conf"
  local lua_workspaces="$target_hypr_dir/workspaces.lua"
  if [[ -f "$old_workspaces" && ! -f "$backup_hypr_dir/workspaces.lua" && -f "$lua_workspaces" ]]; then
    while IFS= read -r line; do
      local rhs="${line#*=}"
      local ws_id="${rhs%%,*}"
      ws_id="$(printf '%s' "$ws_id" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [[ -n "$ws_id" ]] || continue
      local mon_match=""
      if [[ "$rhs" =~ monitor:([^,[:space:]]+) ]]; then
        mon_match="${BASH_REMATCH[1]}"
      fi
      [[ "$mon_match" != desc:* ]] || mon_match=""
      local ws_expr="\"$ws_id\""
      [[ "$ws_id" =~ ^[0-9]+$ ]] && ws_expr="$ws_id"
      if [[ -n "$mon_match" ]]; then
        append_lua_module_line \
          "$lua_workspaces" \
          "workspace = $ws_expr" \
          "hl.workspace_rule({ workspace = $ws_expr, monitor = \"$mon_match\" })"
      fi
    done < <(awk '/^[[:space:]]*workspace[[:space:]]*=/ { print }' "$old_workspaces")
    printf '%s\n' "[INFO] Translated legacy workspaces.conf entries into $lua_workspaces." | tee -a "$log"
  fi
}

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
    while IFS= read -r disabled_cmd; do
      [[ -n "$disabled_cmd" ]] || continue
      append_lua_module_line "$lua_startup" "-- disabled-by-user: exec-once = $disabled_cmd" \
        "-- disabled-by-user: exec-once = $disabled_cmd"
    done <"$disable_tmp"
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

  # 3. Translate legacy WindowRules.conf windowrule/layerrule entries into UserConfigs/WindowRules.lua
  local old_wr="$backup_dir/WindowRules.conf"
  local lua_wr="$target_user_dir/WindowRules.lua"
  if [[ -f "$old_wr" && -f "$lua_wr" ]]; then
    local wr_overlay_tmp wr_disable_tmp wr_empty_base
    wr_overlay_tmp="$(mktemp)"
    wr_disable_tmp="$(mktemp)"
    wr_empty_base="$(mktemp)"
    if declare -F compose_overlay_from_backup >/dev/null 2>&1; then
      compose_overlay_from_backup windowrules "$wr_empty_base" "$old_wr" "$wr_overlay_tmp" "$wr_disable_tmp" || true
    else
      awk '/^[[:space:]]*(windowrule|windowrulev2|layerrule)[[:space:]]*=/ { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }' "$old_wr" | sort -u >"$wr_overlay_tmp" || true
    fi
    while IFS= read -r raw_rule; do
      [[ -n "$raw_rule" ]] || continue
      local lua_rule=""
      if lua_rule="$(translate_legacy_windowrule_line_to_lua "$raw_rule")"; then
        append_lua_module_line "$lua_wr" "$lua_rule" "$lua_rule"
      fi
    done <"$wr_overlay_tmp"
    while IFS= read -r disabled_rule; do
      [[ -n "$disabled_rule" ]] || continue
      append_lua_module_line "$lua_wr" "-- disabled-by-user: $disabled_rule" "-- disabled-by-user: $disabled_rule"
    done <"$wr_disable_tmp"
    rm -f -- "$wr_overlay_tmp" "$wr_disable_tmp" "$wr_empty_base"
    printf '%s\n' "[INFO] Translated legacy WindowRules.conf entries into $lua_wr." | tee -a "$log"
  fi

  # 4. Translate legacy UserKeybinds.conf bind entries into UserConfigs/UserKeybinds.lua
  local old_kb="$backup_dir/UserKeybinds.conf"
  local lua_kb="$target_user_dir/UserKeybinds.lua"
  if [[ -f "$old_kb" && -f "$lua_kb" ]]; then
    while IFS= read -r raw_bind; do
      [[ -n "$raw_bind" ]] || continue
      local lua_bind=""
      if lua_bind="$(translate_legacy_keybind_line_to_lua "$raw_bind")"; then
        local bind_marker="${lua_bind%%, hl.dsp.*}"
        append_lua_module_line "$lua_kb" "$bind_marker" "$lua_bind"
      fi
    done < <(awk '/^[[:space:]]*bind[elmnr]*[[:space:]]*=/ { print }' "$old_kb")
    printf '%s\n' "[INFO] Translated legacy UserKeybinds.conf entries into $lua_kb." | tee -a "$log"
  fi

  # 5. Translate legacy UserSettings.conf kb_layout overrides into UserConfigs/UserSettings.lua
  local old_settings="$backup_dir/UserSettings.conf"
  local lua_settings="$target_user_dir/UserSettings.lua"
  if [[ -f "$old_settings" && -f "$lua_settings" ]]; then
    local legacy_kb=""
    legacy_kb="$(awk -F= '/^[[:space:]]*kb_layout[[:space:]]*=/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }' "$old_settings")"
    if [[ -n "$legacy_kb" && "$legacy_kb" =~ ^[[:alnum:]_,+-]+$ ]]; then
      append_lua_module_line \
        "$lua_settings" \
        "kb_layout = \"$legacy_kb\"" \
        "hl.config({ input = { kb_layout = \"$legacy_kb\" } })"
    fi
    printf '%s\n' "[INFO] Translated legacy UserSettings.conf entries into $lua_settings." | tee -a "$log"
  fi

  # 6. Translate legacy WorkSpaceRules.conf workspace entries into UserConfigs/WorkSpaceRules.lua
  local old_wsr="$backup_dir/WorkSpaceRules.conf"
  local lua_wsr="$target_user_dir/WorkSpaceRules.lua"
  if [[ -f "$old_wsr" && -f "$lua_wsr" ]]; then
    while IFS= read -r line; do
      local rhs="${line#*=}"
      local ws_id="${rhs%%,*}"
      ws_id="$(printf '%s' "$ws_id" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [[ -n "$ws_id" ]] || continue
      local mon_match=""
      if [[ "$rhs" =~ monitor:([^,[:space:]]+) ]]; then
        mon_match="${BASH_REMATCH[1]}"
      fi
      [[ "$mon_match" != desc:* ]] || mon_match=""
      local ws_expr="\"$ws_id\""
      [[ "$ws_id" =~ ^[0-9]+$ ]] && ws_expr="$ws_id"
      if [[ -n "$mon_match" ]]; then
        append_lua_module_line \
          "$lua_wsr" \
          "workspace = $ws_expr" \
          "hl.workspace_rule({ workspace = $ws_expr, monitor = \"$mon_match\" })"
      fi
    done < <(awk '/^[[:space:]]*workspace[[:space:]]*=/ { print }' "$old_wsr")
    printf '%s\n' "[INFO] Translated legacy WorkSpaceRules.conf entries into $lua_wsr." | tee -a "$log"
  fi

  # 7. Translate legacy 01-UserDefaults.conf entries into UserConfigs/01-UserDefaults.lua
  local old_defaults="$backup_dir/01-UserDefaults.conf"
  local lua_defaults="$target_user_dir/01-UserDefaults.lua"
  if [[ -f "$old_defaults" && -f "$lua_defaults" ]]; then
    local legacy_edit legacy_term legacy_files
    legacy_edit="$(awk -F, '/^[[:space:]]*env[[:space:]]*=[[:space:]]*EDITOR[[:space:]]*,/ { gsub(/^[[:space:]\042]+|[[:space:]\042]+$/, "", $2); print $2; exit }' "$old_defaults")"
    if [[ -z "$legacy_edit" ]]; then
      legacy_edit="$(awk -F= '/^[[:space:]]*[$]edit[[:space:]]*=/ { sub(/#.*$/, "", $2); gsub(/^[[:space:]\042]+|[[:space:]\042]+$/, "", $2); print $2; exit }' "$old_defaults")"
    fi
    legacy_term="$(awk -F= '/^[[:space:]]*[$]term[[:space:]]*=/ { sub(/#.*$/, "", $2); gsub(/^[[:space:]\042]+|[[:space:]\042]+$/, "", $2); print $2; exit }' "$old_defaults")"
    legacy_files="$(awk -F= '/^[[:space:]]*[$]files[[:space:]]*=/ { sub(/#.*$/, "", $2); gsub(/^[[:space:]\042]+|[[:space:]\042]+$/, "", $2); print $2; exit }' "$old_defaults")"
    if [[ -n "$legacy_edit" && "$legacy_edit" =~ ^[A-Za-z0-9_./-]+$ ]]; then
      sed -i -E "s|hl\.env\(\"EDITOR\", \"[^\"]+\"\)|hl.env(\"EDITOR\", \"$legacy_edit\")|" "$lua_defaults"
    fi
    if [[ -n "$legacy_term" && "$legacy_term" =~ ^[A-Za-z0-9_./-]+$ ]]; then
      sed -i -E "s|^([[:space:]]*local[[:space:]]+term[[:space:]]*=[[:space:]]*)\"[^\"]+\"|\1\"$legacy_term\"|" "$lua_defaults"
    fi
    if [[ -n "$legacy_files" && "$legacy_files" =~ ^[A-Za-z0-9_./-]+$ ]]; then
      sed -i -E "s|^([[:space:]]*local[[:space:]]+files[[:space:]]*=[[:space:]]*)\"[^\"]+\"|\1\"$legacy_files\"|" "$lua_defaults"
    fi
    printf '%s\n' "[INFO] Translated legacy 01-UserDefaults.conf entries into $lua_defaults." | tee -a "$log"
  fi
}

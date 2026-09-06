#!/usr/bin/env bash
# === 4ndr0666 === #
# Copy helpers split into phases to keep copy.sh lean.

set -Eeuo pipefail

LAST_HYPR_BACKUP_PATH=""

copy_phase1() {
  local log="$1"
  local -a dirs=(fastfetch kitty rofi swaync)

  for dir_name in "${dirs[@]}"; do
    local dir_path="$HOME/.config/$dir_name"
    if [[ -d "$dir_path" ]]; then
      while true; do
        printf '\n%s Found %s config in ~/.config/\n' "${INFO:-[INFO]}" "$dir_name"
        printf '%s' "${CAT:-[ACTION]} Do you want to replace ${YELLOW:-}$dir_name${RESET:-} config? (y/n): "
        read -r choice
        case "$choice" in
          [Yy]*)
            local backup_dir
            backup_dir="$(replace_dir_transaction "config/$dir_name" "$dir_path" "$log")"
            if [[ -n "$backup_dir" ]]; then
              printf '%s\n' "${NOTE:-[NOTE]} - Backed up $dir_name to $backup_dir." | tee -a "$log"
            fi
            printf '%s\n' "${OK:-[OK]} - Replaced $dir_name with new configuration." | tee -a "$log"
            if [[ "$dir_name" == rofi && -n "$backup_dir" ]]; then
              if [[ -d "$backup_dir/themes" ]]; then
                mkdir -p "$HOME/.config/rofi/themes"
                for file in "$backup_dir/themes"/*; do
                  [[ -e "$file" ]] || continue
                  cp -n -- "$file" "$HOME/.config/rofi/themes/" >>"$log" 2>&1
                done
              fi
              if [[ -f "$backup_dir/0-shared-fonts.rasi" ]]; then
                cp -- "$backup_dir/0-shared-fonts.rasi" "$HOME/.config/rofi/0-shared-fonts.rasi" >>"$log" 2>&1
              fi
            fi
            break
            ;;
          [Nn]*)
            printf '%s\n' "${NOTE:-[NOTE]} - Skipping $dir_name" | tee -a "$log"
            break
            ;;
          *)
            printf '%s\n' "${WARN:-[WARN]} - Invalid choice. Please enter Y or N."
            ;;
        esac
      done
    else
      cp -a -- "config/$dir_name" "$dir_path" 2>&1 | tee -a "$log"
      printf '%s\n' "${OK:-[OK]} - Copy completed for $dir_name" | tee -a "$log"
    fi
  done
}

copy_waybar() {
  local log="$1"
  local dir_path="$HOME/.config/waybar"

  if [[ -d "$dir_path" ]]; then
    while true; do
      printf '%s' "${CAT:-[ACTION]} Do you want to replace ${YELLOW:-}waybar${RESET:-} config? (y/n): "
      read -r choice
      case "$choice" in
        [Yy]*)
          local backup_dir
          backup_dir="$(replace_dir_transaction "config/waybar" "$dir_path" "$log")"
          printf '%s\n' "${NOTE:-[NOTE]} - Backed up waybar to ${backup_dir:-none}." | tee -a "$log"

          if [[ -n "$backup_dir" ]]; then
            local file symlink symlink_target symlink_dir target_file
            for file in config style.css; do
              symlink="$backup_dir/$file"
              target_file="$dir_path/$file"
              if [[ -L "$symlink" ]]; then
                symlink_target="$(readlink -- "$symlink")"
                symlink_dir="$(dirname -- "$symlink")"
                if [[ "$symlink_target" == /* ]]; then
                  target_file="$symlink_target"
                else
                  target_file="$symlink_dir/$symlink_target"
                fi
                [[ -f "$target_file" ]] || continue
                rm -f -- "$dir_path/$file"
                cp -f -- "$target_file" "$dir_path/$file"
              fi
            done

            if [[ -d "$backup_dir/configs" ]]; then
              for entry in "$backup_dir/configs"/*; do
                [[ -e "$entry" ]] || continue
                local target="$dir_path/configs/$(basename -- "$entry")"
                [[ -e "$target" ]] && continue
                cp -a -- "$entry" "$dir_path/configs/"
              done
            fi

            if [[ -d "$backup_dir/style" ]]; then
              for entry in "$backup_dir/style"/*; do
                [[ -e "$entry" ]] || continue
                local target="$dir_path/style/$(basename -- "$entry")"
                [[ -e "$target" ]] && continue
                cp -a -- "$entry" "$dir_path/style/"
              done
            fi

            if [[ -f "$backup_dir/UserModules" ]]; then
              cp -f -- "$backup_dir/UserModules" "$dir_path/UserModules"
            fi
          fi
          printf '%s\n' "${OK:-[OK]} - Replaced waybar with new configuration." | tee -a "$log"
          break
          ;;
        [Nn]*)
          printf '%s\n' "${NOTE:-[NOTE]} - Skipping waybar config replacement." | tee -a "$log"
          break
          ;;
        *)
          printf '%s\n' "${WARN:-[WARN]} - Invalid choice. Please enter Y or N."
          ;;
      esac
    done
  else
    cp -a -- "config/waybar" "$dir_path" 2>&1 | tee -a "$log"
    printf '%s\n' "${OK:-[OK]} - Copy completed for waybar" | tee -a "$log"
  fi
}

copy_phase2() {
  local log="$1"
  local -a dirs=(btop cava hypr Kvantum qt5ct qt6ct swappy wallust wlogout)

  for dir_name in "${dirs[@]}"; do
    local dir_path="$HOME/.config/$dir_name"
    local source="config/$dir_name"
    local backup_dir=""

    if [[ -d "$source" ]]; then
      if [[ -e "$dir_path" || -L "$dir_path" ]]; then
        backup_dir="$(replace_dir_transaction "$source" "$dir_path" "$log")"
      else
        mkdir -p -- "$(dirname -- "$dir_path")"
        cp -a -- "$source" "$dir_path" 2>&1 | tee -a "$log"
      fi
      printf '%s\n' "${OK:-[OK]} - Copy of config for $dir_name completed." | tee -a "$log"
    else
      printf '%s\n' "${ERROR:-[ERROR]} - Directory $source does not exist to copy." | tee -a "$log"
      return 1
    fi

    if [[ "$dir_name" == hypr && -n "$backup_dir" ]]; then
      LAST_HYPR_BACKUP_PATH="$backup_dir"
    fi
  done

  install_terminal_configs "$log"
}

restore_hypr_assets() {
  local log="$1"
  local express_mode="$2"
  local hypr_dir="$HOME/.config/hypr"
  local backup_hypr_path="$LAST_HYPR_BACKUP_PATH"

  [[ -n "$backup_hypr_path" && -d "$backup_hypr_path" ]] || return 0
  if [[ "$express_mode" -eq 1 ]]; then
    printf '%s\n' "${NOTE:-[NOTE]} Express mode: skipping automatic restoration of animations and monitor profiles." | tee -a "$log"
    return 0
  fi

  printf '\n%s\n' "${NOTE:-[NOTE]} Restoring user Lua animations and monitor profiles into $hypr_dir..."

  local lua_dir backup_subdir
  for lua_dir in Monitor_Profiles animations; do
    backup_subdir="$backup_hypr_path/$lua_dir"
    if [[ -d "$backup_subdir" && -d "$hypr_dir/$lua_dir" ]]; then
      find "$backup_subdir" -maxdepth 1 -type f -name '*.lua' -exec cp -f -- {} "$hypr_dir/$lua_dir/" \; 2>&1 | tee -a "$log"
      printf '%s\n' "${OK:-[OK]} - Restored Lua profiles: $lua_dir" | tee -a "$log"
    fi
  done

  local wallpaper_backup="$backup_hypr_path/wallpaper_effects"
  if [[ -d "$wallpaper_backup" ]]; then
    rm -rf -- "$hypr_dir/wallpaper_effects"
    cp -a -- "$wallpaper_backup" "$hypr_dir/" 2>&1 | tee -a "$log"
    printf '%s\n' "${OK:-[OK]} - Restored directory: wallpaper_effects" | tee -a "$log"
  fi

  local file_restore backup_file
  for file_restore in monitors.lua workspaces.lua; do
    backup_file="$backup_hypr_path/$file_restore"
    if [[ -f "$backup_file" ]]; then
      cp -f -- "$backup_file" "$hypr_dir/$file_restore" 2>&1 | tee -a "$log"
      printf '%s\n' "${OK:-[OK]} - Restored file: $file_restore" | tee -a "$log"
    fi
  done
}

compose_overlay_from_backup() {
  local type="$1"
  local base_file="$2"
  local old_user_file="$3"
  local new_user_file="$4"
  local disable_file="$5"
  local old_tmp base_tmp

  mkdir -p -- "$(dirname -- "$new_user_file")"
  old_tmp="$(mktemp)"
  base_tmp="$(mktemp)"
  trap 'rm -f -- "$old_tmp" "$base_tmp"' RETURN
  : >"$new_user_file"
  : >"$disable_file"

  case "$type" in
    startup)
      grep -E '^\s*exec-once\s*=' "$old_user_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$old_tmp" || true
      grep -E '^\s*exec-once\s*=' "$base_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$base_tmp" || true
      comm -23 "$old_tmp" "$base_tmp" >"$new_user_file"
      grep -E '^\s*#\s*exec-once\s*=' "$old_user_file" |
        sed -E 's/^\s*#\s*exec-once\s*=\s*//' |
        sed -E 's/^\s+//;s/\s+$//' |
        grep -Ev '^\$scriptsDir/KeybindsLayoutInit\.sh$' |
        sort -u >"$disable_file" || true
      ;;
    windowrules)
      grep -E '^(windowrule|layerrule)\s*=' "$old_user_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$old_tmp" || true
      grep -E '^(windowrule|layerrule)\s*=' "$base_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$base_tmp" || true
      comm -23 "$old_tmp" "$base_tmp" >"$new_user_file"
      grep -E '^\s*#\s*(windowrule|layerrule)\s*=' "$old_user_file" |
        sed -E 's/^\s*#\s*//' |
        sed -E 's/^\s+//;s/\s+$//' |
        sort -u >"$disable_file" || true
      ;;
    *)
      printf '%s\n' "unsupported overlay type: $type" >&2
      return 2
      ;;
  esac
}

cleanup_duplicate_userconfigs() {
  local current_version="$1"
  local log="$2"

  [[ -n "$current_version" ]] || return 0
  if version_gte "$current_version" "2.3.20"; then
    printf '%s\n' "${INFO:-[INFO]} Skipping UserConfigs duplicate cleanup for detected version v$current_version (>= 2.3.20)." | tee -a "$log"
    return 0
  fi

  printf '%s\n' "${INFO:-[INFO]} Running UserConfigs duplicate cleanup for detected version v$current_version (<= 2.3.19)." | tee -a "$log"

  local hypr_dir="$HOME/.config/hypr"
  local base_dir="$hypr_dir/configs"
  local user_dir="$hypr_dir/UserConfigs"
  local start_base="$base_dir/Startup_Apps.conf"
  local start_user="$user_dir/Startup_Apps.conf"
  local window_base="$base_dir/WindowRules.conf"
  local window_user="$user_dir/WindowRules.conf"
  local keybind_base="$base_dir/Keybinds.conf"
  local keybind_user="$user_dir/UserKeybinds.conf"
  local tmp backup

  if [[ -f "$start_base" && -f "$start_user" ]]; then
    tmp="$(mktemp)"
    backup="$start_user.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    awk '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR==NR { if ($0 ~ /^[ \t]*exec-once[ \t]*=/) base[trim($0)]=1; next }
      { if ($0 ~ /^[ \t]*exec-once[ \t]*=/ && trim($0) in base) next; print }
    ' "$start_base" "$start_user" >"$tmp"
    if ! cmp -s "$start_user" "$tmp"; then
      cp -f -- "$start_user" "$backup"
      mv -- "$tmp" "$start_user"
      printf '%s\n' "${NOTE:-[NOTE]} - Removed duplicate Startup_Apps entries matching base config." | tee -a "$log"
    else
      rm -f -- "$tmp"
    fi
  fi

  if [[ -f "$window_base" && -f "$window_user" ]]; then
    tmp="$(mktemp)"
    backup="$window_user.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    awk '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR==NR { if ($0 ~ /^[ \t]*(windowrule|layerrule)[ \t]*=/) base[trim($0)]=1; next }
      { if ($0 ~ /^[ \t]*(windowrule|layerrule)[ \t]*=/ && trim($0) in base) next; print }
    ' "$window_base" "$window_user" >"$tmp"
    if ! cmp -s "$window_user" "$tmp"; then
      cp -f -- "$window_user" "$backup"
      mv -- "$tmp" "$window_user"
      printf '%s\n' "${NOTE:-[NOTE]} - Removed duplicate WindowRules entries matching base config." | tee -a "$log"
    else
      rm -f -- "$tmp"
    fi
  fi

  if [[ -f "$keybind_base" && -f "$keybind_user" ]]; then
    tmp="$(mktemp)"
    backup="$keybind_user.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    awk '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR==NR { if ($0 ~ /^[ \t]*bind[a-z]*[ \t]*=/) base[trim($0)]=1; next }
      { if ($0 ~ /^[ \t]*bind[a-z]*[ \t]*=/ && trim($0) in base) next; print }
    ' "$keybind_base" "$keybind_user" >"$tmp"
    if ! cmp -s "$keybind_user" "$tmp"; then
      cp -f -- "$keybind_user" "$backup"
      mv -- "$tmp" "$keybind_user"
      printf '%s\n' "${NOTE:-[NOTE]} - Removed duplicate UserKeybinds entries matching base Keybinds.conf." | tee -a "$log"
    else
      rm -f -- "$tmp"
    fi
  fi
}

restore_user_configs() {
  local log="$1"
  local express_mode="$2"
  local old_version="$3"
  local dirpath="$HOME/.config/hypr"
  local backup_dir_path="$LAST_HYPR_BACKUP_PATH/UserConfigs"

  [[ -n "$LAST_HYPR_BACKUP_PATH" && -d "$backup_dir_path" ]] || return 0
  if [[ "$express_mode" -eq 1 ]]; then
    printf '%s\n' "${NOTE:-[NOTE]} Express mode: skipping UserConfigs restoration prompts." | tee -a "$log"
  else
    local current_version="${old_version:-999.9.9}"
    local target_version="2.3.19"
    printf '%s\n' "${NOTE:-[NOTE]} Restoring previous User-Configs..." | tee -a "$log"

    if version_gte "$current_version" "$target_version"; then
      read -r -p "${CAT:-[ACTION]} Do you want to restore your previous UserConfigs directory? (Y/n): " restore_dir
      if [[ "$restore_dir" != [Nn]* ]]; then
        mkdir -p -- "$dirpath/UserConfigs"
        rsync -a -- "$backup_dir_path/" "$dirpath/UserConfigs/" 2>&1 | tee -a "$log"
        printf '%s\n' "${OK:-[OK]} - UserConfigs directory restored." | tee -a "$log"
      else
        printf '%s\n' "${NOTE:-[NOTE]} - Skipped restoring UserConfigs." | tee -a "$log"
      fi
    else
      printf '%s\n' "${NOTE:-[NOTE]} Detected version v$current_version (older than v$target_version). Using legacy restoration mode." | tee -a "$log"
      local -a files=(01-UserDefaults.conf ENVariables.conf LaptopDisplay.conf Laptops.conf Startup_Apps.conf UserDecorations.conf UserAnimations.conf UserKeybinds.conf UserSettings.conf WindowRules.conf)
      local file_name backup_file
      mkdir -p -- "$dirpath/UserConfigs"
      for file_name in "${files[@]}"; do
        backup_file="$backup_dir_path/$file_name"
        [[ -f "$backup_file" ]] || continue
        printf '\n%s Found %s in hypr backup...\n' "${INFO:-[INFO]}" "$file_name"
        read -r -p "${CAT:-[ACTION]} Do you want to restore $file_name from backup? (Y/n): " restore_file
        if [[ "$restore_file" != [Nn]* ]]; then
          cp -f -- "$backup_file" "$dirpath/UserConfigs/$file_name"
          printf '%s\n' "${OK:-[OK]} - $file_name restored!" | tee -a "$log"
        else
          printf '%s\n' "${NOTE:-[NOTE]} - Skipped restoring $file_name." | tee -a "$log"
        fi
      done
    fi
  fi

  local detected_version="${old_version:-}"
  if [[ -z "$detected_version" ]]; then
    detected_version="$(get_installed_dotfiles_version)"
  fi
  [[ -n "$detected_version" ]] && cleanup_duplicate_userconfigs "$detected_version" "$log"
}

restore_user_scripts() {
  local log="$1"
  local express_mode="$2"
  local dirpath="$HOME/.config/hypr"
  local backup_dir_path="$LAST_HYPR_BACKUP_PATH/UserScripts"
  local -a scripts_to_restore=(RofiBeats.sh Weather.py Weather.sh)

  [[ -n "$LAST_HYPR_BACKUP_PATH" && -d "$backup_dir_path" ]] || return 0
  [[ "$express_mode" -eq 1 ]] && { printf '%s\n' "${NOTE:-[NOTE]} Express mode: skipping UserScripts restoration prompts." | tee -a "$log"; return 0; }

  printf '%s\n' "${NOTE:-[NOTE]} Restoring previous User-Scripts..." | tee -a "$log"
  local script_name backup_script
  for script_name in "${scripts_to_restore[@]}"; do
    backup_script="$backup_dir_path/$script_name"
    [[ -f "$backup_script" ]] || continue
    printf '\n%s Found %s in hypr backup...\n' "${INFO:-[INFO]}" "$script_name"
    read -r -p "${CAT:-[ACTION]} Do you want to restore $script_name from backup? (y/N): " restore_script
    if [[ "$restore_script" == [Yy]* ]]; then
      cp -f -- "$backup_script" "$dirpath/UserScripts/$script_name"
      printf '%s\n' "${OK:-[OK]} - $script_name restored!" | tee -a "$log"
    else
      printf '%s\n' "${NOTE:-[NOTE]} - Skipped restoring $script_name." | tee -a "$log"
    fi
  done
}

restore_hypr_files() {
  local log="$1"
  local express_mode="$2"
  local dirpath="$HOME/.config/hypr"
  local backup_dir_path="$LAST_HYPR_BACKUP_PATH"
  local -a files=(hyprlock.conf hypridle.conf)

  [[ -n "$backup_dir_path" && -d "$backup_dir_path" ]] || return 0
  [[ "$express_mode" -eq 1 ]] && { printf '%s\n' "${NOTE:-[NOTE]} Express mode: skipping individual hypr file restoration prompts." | tee -a "$log"; return 0; }

  printf '%s\n' "${NOTE:-[NOTE]} Restoring selected files in $dirpath..." | tee -a "$log"
  local file_restore backup_file
  for file_restore in "${files[@]}"; do
    backup_file="$backup_dir_path/$file_restore"
    [[ -f "$backup_file" ]] || continue
    printf '\n%s Found %s in hypr backup...\n' "${INFO:-[INFO]}" "$file_restore"
    read -r -p "${CAT:-[ACTION]} Do you want to restore $file_restore from backup? (y/N): " restore_file
    if [[ "$restore_file" == [Yy]* ]]; then
      cp -f -- "$backup_file" "$dirpath/$file_restore"
      printf '%s\n' "${OK:-[OK]} - $file_restore restored!" | tee -a "$log"
    else
      printf '%s\n' "${NOTE:-[NOTE]} - Skipped restoring $file_restore." | tee -a "$log"
    fi
  done
}

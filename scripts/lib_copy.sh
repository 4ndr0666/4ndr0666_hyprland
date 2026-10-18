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
                local target
                target="$dir_path/configs/$(basename -- "$entry")"
                [[ -e "$target" ]] && continue
                cp -a -- "$entry" "$dir_path/configs/"
              done
            fi

            if [[ -d "$backup_dir/style" ]]; then
              for entry in "$backup_dir/style"/*; do
                [[ -e "$entry" ]] || continue
                local target
                target="$dir_path/style/$(basename -- "$entry")"
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

archive_legacy_conf() {
  local source="$1"
  local archive_root="$2"
  local relative="$3"
  local log="$4"
  local destination="$archive_root/$relative"

  [[ -f "$source" || -L "$source" ]] || {
    printf '[ERROR] Legacy configuration source is missing: %s\n' "$source" >&2
    return 1
  }
  mkdir -p -- "$(dirname -- "$destination")"
  if [[ -e "$destination" || -L "$destination" ]]; then
    if cmp -s -- "$source" "$destination"; then
      printf '%s\n' "[INFO] Legacy configuration already preserved: $destination" | tee -a "$log"
      return 0
    fi
    destination="${destination}.preserved-$(date +%Y%m%dT%H%M%S%N)"
  fi
  cp -a -- "$source" "$destination"
  printf '%s\n' "[WARN] Preserved inactive legacy .conf at $destination; the Lua runtime does not load it automatically." | tee -a "$log"
}

archive_legacy_conf_files() {
  local source_root="$1"
  local archive_root="$2"
  local log="$3"
  local remove_source="${4:-0}"
  local source relative

  [[ -d "$source_root" ]] || return 0
  while IFS= read -r -d '' source; do
    relative="${source#"$source_root"/}"
    archive_legacy_conf "$source" "$archive_root" "$relative" "$log"
    if [[ "$remove_source" == 1 ]]; then
      rm -f -- "$source"
    fi
  done < <(find "$source_root" -path "$source_root/legacy-conf-backup" -prune -o \( -type f -o -type l \) -name '*.conf' -print0 | sort -z)
}

cleanup_duplicate_userconfigs() {
  local current_version="$1"
  local log="$2"
  local user_dir="$HOME/.config/hypr/UserConfigs"

  [[ -n "$current_version" ]] || return 0
  if version_gte "$current_version" "2.3.20"; then
    printf '%s\n' "[INFO] Reconciling UserConfigs for Lua runtime on v$current_version." | tee -a "$log"
  else
    printf '%s\n' "[WARN] Legacy v$current_version UserConfigs use .conf syntax; archiving inactive files instead of editing them as live configuration." | tee -a "$log"
  fi
  archive_legacy_conf_files "$user_dir" "$user_dir/legacy-conf-backup" "$log" 1
}

restore_user_configs() {
  local log="$1"
  local express_mode="$2"
  local old_version="$3"
  local dirpath="$HOME/.config/hypr"
  local backup_dir_path="$LAST_HYPR_BACKUP_PATH/UserConfigs"
  local legacy_archive="$dirpath/UserConfigs/legacy-conf-backup"

  [[ -n "$LAST_HYPR_BACKUP_PATH" && -d "$backup_dir_path" ]] || return 0
  if [[ "$express_mode" -eq 1 ]]; then
    printf '%s\n' "[NOTE] Express mode: skipping UserConfigs restoration prompts." | tee -a "$log"
  else
    local current_version="${old_version:-999.9.9}"
    local target_version="2.3.19"
    printf '%s\n' "[NOTE] Restoring previous User-Configs..." | tee -a "$log"

    if version_gte "$current_version" "$target_version"; then
      read -r -p "[ACTION] Do you want to restore your previous UserConfigs directory? (Y/n): " restore_dir
      if [[ "$restore_dir" != [Nn]* ]]; then
        mkdir -p -- "$dirpath/UserConfigs"
        archive_legacy_conf_files "$backup_dir_path" "$legacy_archive" "$log"
        if command -v rsync >/dev/null 2>&1; then
          rsync -a --exclude='*.conf' --exclude='legacy-conf-backup/' -- "$backup_dir_path/" "$dirpath/UserConfigs/" 2>&1 | tee -a "$log"
        else
          while IFS= read -r -d '' item; do
            local rel="${item#"$backup_dir_path"/}"
            mkdir -p -- "$(dirname -- "$dirpath/UserConfigs/$rel")"
            cp -a -- "$item" "$dirpath/UserConfigs/$rel"
          done < <(find "$backup_dir_path" -path "$backup_dir_path/legacy-conf-backup" -prune -o \( -type f -o -type l \) ! -name '*.conf' -print0 | sort -z)
        fi
        if declare -F translate_legacy_userconfigs_to_lua >/dev/null 2>&1; then
          translate_legacy_userconfigs_to_lua "$backup_dir_path" "$dirpath/UserConfigs" "$log"
        fi
        printf '%s\n' "[OK] Restored Lua-compatible UserConfigs; legacy .conf files were preserved separately." | tee -a "$log"
      else
        printf '%s\n' "[NOTE] Skipped restoring UserConfigs." | tee -a "$log"
      fi
    else
      printf '%s\n' "[NOTE] Detected version v$current_version (older than v$target_version). Using legacy preservation mode." | tee -a "$log"
      local -a files=()
      local file_name backup_file
      while IFS= read -r -d '' file_name; do
        files+=("$file_name")
      done < <(find "$backup_dir_path" -path "$backup_dir_path/legacy-conf-backup" -prune -o \( -type f -o -type l \) -name '*.conf' -printf '%P\0' | sort -z)

      if (("${#files[@]}" == 0)); then
        printf '%s\n' "[INFO] No legacy .conf UserConfigs files were found." | tee -a "$log"
      fi
      for file_name in "${files[@]}"; do
        backup_file="$backup_dir_path/$file_name"
        printf '\n%s Found legacy %s in the Hyprland backup.\n' "[INFO]" "$file_name"
        read -r -p "[ACTION] Preserve inactive legacy $file_name in legacy-conf-backup? (Y/n): " restore_file
        if [[ "$restore_file" != [Nn]* ]]; then
          archive_legacy_conf "$backup_file" "$legacy_archive" "$file_name" "$log"
          if declare -F translate_legacy_userconfigs_to_lua >/dev/null 2>&1; then
            translate_legacy_userconfigs_to_lua "$backup_dir_path" "$dirpath/UserConfigs" "$log"
          fi
        else
          printf '%s\n' "[NOTE] Skipped preserving $file_name by request." | tee -a "$log"
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

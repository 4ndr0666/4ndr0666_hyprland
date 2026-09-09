#!/usr/bin/env bash
# === 4ndr0666 === #
# Resolution-profile customization owns its own reversible transaction.

set -Eeuo pipefail

apply_resolution_profile() {
  local resolution="$1"
  [[ "$resolution" == '< 1440p' ]] || return 0

  local kitty="$HOME/.config/kitty/kitty.conf"
  local lock="$HOME/.config/hypr/hyprlock.conf"
  local lock1080="$HOME/.config/hypr/hyprlock-1080p.conf"
  local lock2k="$HOME/.config/hypr/hyprlock-2k.conf"
  local rofi="$HOME/.config/rofi/0-shared-fonts.rasi"
  local transaction_dir=""
  local log="${LOG:-/dev/null}"

  transaction_dir="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-resolution.XXXXXX")"
  trap 'if [[ -n "${transaction_dir:-}" && -d "$transaction_dir" ]]; then rm -rf -- "$transaction_dir"; fi' RETURN

  local -a targets=("$kitty" "$lock" "$lock1080" "$lock2k" "$rofi")
  local target snapshot marker
  for target in "${targets[@]}"; do
    marker="$transaction_dir/$(printf '%s' "$target" | sha256sum | cut -d' ' -f1).exists"
    if [[ -e "$target" || -L "$target" ]]; then
      snapshot="$transaction_dir/$(basename -- "$marker").snapshot"
      cp -a -- "$target" "$snapshot"
      : >"$marker"
    fi
  done

  resolution_profile_rollback() {
    local rollback_target rollback_snapshot rollback_marker
    for rollback_target in "${targets[@]}"; do
      rollback_marker="$transaction_dir/$(printf '%s' "$rollback_target" | sha256sum | cut -d' ' -f1).exists"
      rollback_snapshot="$transaction_dir/$(basename -- "$rollback_marker").snapshot"
      rm -rf -- "$rollback_target"
      if [[ -f "$rollback_marker" ]]; then
        cp -a -- "$rollback_snapshot" "$rollback_target"
      fi
    done
  }

  resolution_profile_commit() {
    local source_temp
    if [[ -f "$kitty" ]]; then
      source_temp="$(mktemp --tmpdir="$(dirname -- "$kitty")" '.resolution.XXXXXX')"
      cp -a -- "$kitty" "$source_temp"
      sed -i 's/font_size 16.0/font_size 14.0/' "$source_temp"
      mv -- "$source_temp" "$kitty"
    fi

    if [[ -f "$lock" && -f "$lock1080" ]]; then
      mv -- "$lock" "$lock2k"
      mv -- "$lock1080" "$lock"
    fi

    if [[ -f "$rofi" ]]; then
      source_temp="$(mktemp --tmpdir="$(dirname -- "$rofi")" '.resolution.XXXXXX')"
      cp -a -- "$rofi" "$source_temp"
      sed -i '/element-text {/,/}/s/[[:space:]]*font: "JetBrainsMono Nerd Font SemiBold 13"/font: "JetBrainsMono Nerd Font SemiBold 11"/' "$source_temp"
      sed -i '/configuration {/,/}/s/[[:space:]]*font: "JetBrainsMono Nerd Font SemiBold 15"/font: "JetBrainsMono Nerd Font SemiBold 13"/' "$source_temp"
      mv -- "$source_temp" "$rofi"
    fi
  }

  if ! resolution_profile_commit 2>&1 | tee -a "$log"; then
    if ! resolution_profile_rollback 2>&1 | tee -a "$log"; then
      printf '%s\n' '[ERROR] Resolution-profile rollback failed.' >&2
      return 1
    fi
    printf '%s\n' '[ERROR] Resolution-profile transaction failed; prior state restored.' >&2
    return 1
  fi

  printf '%s\n' '[OK] Resolution-profile customization committed.' | tee -a "$log"
}

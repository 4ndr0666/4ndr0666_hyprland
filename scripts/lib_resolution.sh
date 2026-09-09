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
  local kitty_temp=""
  local rofi_temp=""
  local log="${LOG:-/dev/null}"

  transaction_dir="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-resolution.XXXXXX")"
  trap 'rm -f -- "$kitty_temp" "$rofi_temp"; if [[ -n "${transaction_dir:-}" && -d "$transaction_dir" ]]; then rm -rf -- "$transaction_dir"; fi' RETURN

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

  if {
    if [[ -f "$kitty" ]]; then
      kitty_temp="$(mktemp --tmpdir="$(dirname -- "$kitty")" '.resolution.XXXXXX')"
      cp -a -- "$kitty" "$kitty_temp"
      sed -i 's/font_size 16.0/font_size 14.0/' "$kitty_temp"
      mv -- "$kitty_temp" "$kitty"
      kitty_temp=""
    fi

    if [[ -f "$lock" && -f "$lock1080" ]]; then
      mv -- "$lock" "$lock2k"
      mv -- "$lock1080" "$lock"
    fi

    if [[ -f "$rofi" ]]; then
      rofi_temp="$(mktemp --tmpdir="$(dirname -- "$rofi")" '.resolution.XXXXXX')"
      cp -a -- "$rofi" "$rofi_temp"
      sed -i '/element-text {/,/}/s/[[:space:]]*font: "JetBrainsMono Nerd Font SemiBold 13"/font: "JetBrainsMono Nerd Font SemiBold 11"/' "$rofi_temp"
      sed -i '/configuration {/,/}/s/[[:space:]]*font: "JetBrainsMono Nerd Font SemiBold 15"/font: "JetBrainsMono Nerd Font SemiBold 13"/' "$rofi_temp"
      mv -- "$rofi_temp" "$rofi"
      rofi_temp=""
    fi
  } 2>&1 | tee -a "$log"; then
    printf '%s\n' '[OK] Resolution-profile customization committed.' | tee -a "$log"
    return 0
  fi

  local rollback_target rollback_snapshot rollback_marker
  for rollback_target in "${targets[@]}"; do
    rollback_marker="$transaction_dir/$(printf '%s' "$rollback_target" | sha256sum | cut -d' ' -f1).exists"
    rollback_snapshot="$transaction_dir/$(basename -- "$rollback_marker").snapshot"
    rm -rf -- "$rollback_target"
    if [[ -f "$rollback_marker" ]]; then
      cp -a -- "$rollback_snapshot" "$rollback_target"
    fi
  done

  printf '%s\n' '[ERROR] Resolution-profile transaction failed; prior state restored.' >&2
  return 1
}

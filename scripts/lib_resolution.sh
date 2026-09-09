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
  local rollback_failed=0

  transaction_dir="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-resolution.XXXXXX")" || return 1
  trap 'rm -f -- "$kitty_temp" "$rofi_temp"; if [[ -n "${transaction_dir:-}" && -d "$transaction_dir" ]]; then rm -rf -- "$transaction_dir"; fi' RETURN

  local -a targets=("$kitty" "$lock" "$lock1080" "$lock2k" "$rofi")
  local target snapshot marker
  for target in "${targets[@]}"; do
    marker="$transaction_dir/$(printf '%s' "$target" | sha256sum | cut -d' ' -f1).exists"
    if [[ -e "$target" || -L "$target" ]]; then
      snapshot="$transaction_dir/$(basename -- "$marker").snapshot"
      cp -a -- "$target" "$snapshot" || return 1
      : >"$marker" || return 1
    fi
  done

  if [[ -f "$kitty" ]]; then
    kitty_temp="$(mktemp --tmpdir="$(dirname -- "$kitty")" '.resolution.XXXXXX')" || return 1
    cp -a -- "$kitty" "$kitty_temp" || return 1
    sed -i 's/font_size 16.0/font_size 14.0/' "$kitty_temp" || return 1
    mv -- "$kitty_temp" "$kitty" || return 1
    kitty_temp=""
  fi

  if [[ -f "$lock" && -f "$lock1080" ]]; then
    if ! mv -- "$lock" "$lock2k"; then
      rollback_failed=1
    elif ! mv -- "$lock1080" "$lock"; then
      rollback_failed=1
    fi
  fi

  if ((rollback_failed == 0)) && [[ -f "$rofi" ]]; then
    rofi_temp="$(mktemp --tmpdir="$(dirname -- "$rofi")" '.resolution.XXXXXX')" || rollback_failed=1
    if ((rollback_failed == 0)); then cp -a -- "$rofi" "$rofi_temp" || rollback_failed=1; fi
    if ((rollback_failed == 0)); then sed -i '/element-text {/,/}/s/[[:space:]]*font: "JetBrainsMono Nerd Font SemiBold 13"/font: "JetBrainsMono Nerd Font SemiBold 11"/' "$rofi_temp" || rollback_failed=1; fi
    if ((rollback_failed == 0)); then sed -i '/configuration {/,/}/s/[[:space:]]*font: "JetBrainsMono Nerd Font SemiBold 15"/font: "JetBrainsMono Nerd Font SemiBold 13"/' "$rofi_temp" || rollback_failed=1; fi
    if ((rollback_failed == 0)); then mv -- "$rofi_temp" "$rofi" || rollback_failed=1; fi
    if ((rollback_failed == 0)); then rofi_temp=""; fi
  fi

  if ((rollback_failed)); then
    local rollback_target rollback_snapshot rollback_marker
    rollback_failed=0
    for rollback_target in "${targets[@]}"; do
      rollback_marker="$transaction_dir/$(printf '%s' "$rollback_target" | sha256sum | cut -d' ' -f1).exists"
      rollback_snapshot="$transaction_dir/$(basename -- "$rollback_marker").snapshot"
      rm -rf -- "$rollback_target" || rollback_failed=1
      if [[ -f "$rollback_marker" ]]; then
        cp -a -- "$rollback_snapshot" "$rollback_target" || rollback_failed=1
      fi
    done
    if ((rollback_failed)); then
      printf '%s\n' '[ERROR] Resolution-profile rollback failed.' >&2
      return 1
    fi
    printf '%s\n' '[ERROR] Resolution-profile transaction failed; prior state restored.' >&2
    return 1
  fi

  printf '%s\n' '[OK] Resolution-profile customization committed.' | tee -a "$log" || return 1
}

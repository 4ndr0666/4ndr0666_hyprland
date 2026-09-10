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

# Overlay composition is consumed by the copy/upgrade transaction. The legacy
# implementation used grep pipelines followed by `|| true`, which made both
# expected "no match" statuses and real I/O/read errors indistinguishable.
# Keep the capability intact while making the extraction boundary fail-closed
# and the two generated artifacts atomic.
compose_overlay_from_backup() {
  local type="$1"
  local base_file="$2"
  local old_user_file="$3"
  local new_user_file="$4"
  local disable_file="$5"
  local old_tmp base_tmp new_tmp disable_tmp

  mkdir -p -- "$(dirname -- "$new_user_file")" "$(dirname -- "$disable_file")"
  old_tmp="$(mktemp)"
  base_tmp="$(mktemp)"
  new_tmp="$(mktemp --tmpdir="$(dirname -- "$new_user_file")" '.overlay.XXXXXX')"
  disable_tmp="$(mktemp --tmpdir="$(dirname -- "$disable_file")" '.overlay.XXXXXX')"
  trap 'rm -f -- "$old_tmp" "$base_tmp" "$new_tmp" "$disable_tmp"' RETURN

  case "$type" in
    startup)
      awk '/^[[:space:]]*exec-once[[:space:]]*=/ { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }' "$old_user_file" | sort -u >"$old_tmp" || return 1
      awk '/^[[:space:]]*exec-once[[:space:]]*=/ { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }' "$base_file" | sort -u >"$base_tmp" || return 1
      comm -23 "$old_tmp" "$base_tmp" >"$new_tmp" || return 1
      awk '/^[[:space:]]*#[[:space:]]*exec-once[[:space:]]*=/ {
        sub(/^[[:space:]]*#[[:space:]]*exec-once[[:space:]]*=[[:space:]]*/, "")
        sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, "")
        if ($0 != "" && $0 != "$scriptsDir/KeybindsLayoutInit.sh") print
      }' "$old_user_file" | sort -u >"$disable_tmp" || return 1
      ;;
    windowrules)
      awk '/^(windowrule|layerrule)[[:space:]]*=/ { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }' "$old_user_file" | sort -u >"$old_tmp" || return 1
      awk '/^(windowrule|layerrule)[[:space:]]*=/ { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print }' "$base_file" | sort -u >"$base_tmp" || return 1
      comm -23 "$old_tmp" "$base_tmp" >"$new_tmp" || return 1
      awk '/^[[:space:]]*#[[:space:]]*(windowrule|layerrule)[[:space:]]*=/ {
        sub(/^[[:space:]]*#[[:space:]]*/, "")
        sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, "")
        if ($0 != "") print
      }' "$old_user_file" | sort -u >"$disable_tmp" || return 1
      ;;
    *)
      printf '%s\n' "unsupported overlay type: $type" >&2
      return 2
      ;;
  esac

  mv -- "$new_tmp" "$new_user_file" || return 1
  mv -- "$disable_tmp" "$disable_file" || return 1
}

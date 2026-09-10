#!/usr/bin/env bash
# === 4ndr0666 === #
# Waybar link ownership and rollback boundary.

set -Eeuo pipefail

waybar_link_transaction() (
  local chassis_type="$1"
  local log="$2"
  local waybar_dir="$HOME/.config/waybar"
  local config_link="$waybar_dir/config"
  local style_link="$waybar_dir/style.css"
  local config_target
  local config_remove
  local transaction_dir=""
  local rollback_failed=0

  if [[ "$chassis_type" == desktop ]]; then
    config_target="$waybar_dir/configs/[TOP] Default"
    config_remove=" Laptop"
  else
    config_target="$waybar_dir/configs/[TOP] Default Laptop"
    config_remove=""
  fi

  transaction_dir="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-waybar-links.XXXXXX")" || return 1
  trap 'if [[ -n "${transaction_dir:-}" && -d "$transaction_dir" ]]; then rm -rf -- "$transaction_dir"; fi' EXIT

  local -a targets=(
    "$config_link"
    "$style_link"
    "$waybar_dir/configs/[TOP] Default"
    "$waybar_dir/configs/[TOP] Default Laptop"
    "$waybar_dir/configs/[BOT] Default"
    "$waybar_dir/configs/[BOT] Default Laptop"
    "$waybar_dir/configs/[TOP] Default (old v1)"
    "$waybar_dir/configs/[TOP] Default Laptop (old v1)"
    "$waybar_dir/configs/[TOP] Default (old v2)"
    "$waybar_dir/configs/[TOP] Default Laptop (old v2)"
    "$waybar_dir/configs/[TOP] Default (old v3)"
    "$waybar_dir/configs/[TOP] Default Laptop (old v3)"
    "$waybar_dir/configs/[TOP] Default (old v4)"
    "$waybar_dir/configs/[TOP] Default Laptop (old v4)"
  )

  local target snapshot marker hash
  for target in "${targets[@]}"; do
    hash="$(printf '%s' "$target" | sha256sum | cut -d' ' -f1)"
    marker="$transaction_dir/$hash.exists"
    snapshot="$transaction_dir/$hash.snapshot"
    if [[ -e "$target" || -L "$target" ]]; then
      cp -a -- "$target" "$snapshot" || return 1
      : >"$marker" || return 1
    fi
  done

  if ! {
    if [[ -e "$config_link" && ! -L "$config_link" ]]; then
      rm -rf -- "$config_link"
    fi
    ln -sfn -- "$config_target" "$config_link"

    local remove_target
    for remove_target in \
      "$waybar_dir/configs/[TOP] Default$config_remove" \
      "$waybar_dir/configs/[BOT] Default$config_remove" \
      "$waybar_dir/configs/[TOP] Default$config_remove (old v1)" \
      "$waybar_dir/configs/[TOP] Default$config_remove (old v2)" \
      "$waybar_dir/configs/[TOP] Default$config_remove (old v3)" \
      "$waybar_dir/configs/[TOP] Default$config_remove (old v4)"; do
      rm -rf -- "$remove_target"
    done

    if [[ -e "$style_link" && ! -L "$style_link" ]]; then
      rm -rf -- "$style_link"
    fi
    ln -sfn -- "style/[Extra] Neon Circuit.css" "$style_link"
  }; then
    local rollback_target rollback_snapshot rollback_marker rollback_hash
    for rollback_target in "${targets[@]}"; do
      rollback_hash="$(printf '%s' "$rollback_target" | sha256sum | cut -d' ' -f1)"
      rollback_marker="$transaction_dir/$rollback_hash.exists"
      rollback_snapshot="$transaction_dir/$rollback_hash.snapshot"
      rm -rf -- "$rollback_target" || rollback_failed=1
      if [[ -f "$rollback_marker" ]]; then
        cp -a -- "$rollback_snapshot" "$rollback_target" || rollback_failed=1
      fi
    done
    if ((rollback_failed)); then
      printf '%s\n' '[ERROR] Waybar link transaction rollback failed.' >&2
      return 1
    fi
    printf '%s\n' '[ERROR] Waybar link transaction failed; prior state restored.' >&2
    return 1
  fi

  printf '%s\n' '[OK] Waybar links committed.' | tee -a "$log" || return 1
)

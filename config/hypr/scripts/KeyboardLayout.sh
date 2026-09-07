#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# This is for changing kb_layouts. Set kb_layouts in "$HOME/.config/hypr/UserConfigs/UserSettings.conf"

set -Eeuo pipefail

notif_icon="$HOME/.config/swaync/images/ja.png"

ignore_patterns=(
  "--(avrcp)"
  "Bluetooth Speaker"
  "Other Device
  Name"
)

devices_json="$(hyprctl devices -j)"

is_ignored() {
  local device_name="$1"
  local pattern
  for pattern in "${ignore_patterns[@]}"; do
    if [[ "$device_name" == *"$pattern"* ]]; then
      return 0
    fi
  done
  return 1
}

mapfile -t keyboard_names < <(jq -r '.keyboards[].name' <<<"$devices_json")

layout_mapping=()
variant_mapping=()
layout_index=''

for name in "${keyboard_names[@]}"; do
  if is_ignored "$name"; then
    continue
  fi

  mapfile -t layout_mapping < <(jq -r --arg name "$name" '.keyboards[] | select(.name == $name) | .layout | split(",")[]' <<<"$devices_json")
  mapfile -t variant_mapping < <(jq -r --arg name "$name" '.keyboards[] | select(.name == $name) | .variant // "" | split(",")[]' <<<"$devices_json")
  layout_index="$(jq -r --arg name "$name" '.keyboards[] | select(.name == $name) | .active_layout_index' <<<"$devices_json")"
  break
done

if ((${#layout_mapping[@]} == 0)); then
  printf '%s\n' 'Could not get current keyboard layout information: no usable keyboard was found.' >&2
  notify-send -u low -t 2000 'kb_layout' 'Layout change failed' 2>/dev/null || true
  exit 1
fi

if ! [[ "$layout_index" =~ ^[0-9]+$ ]] || ((layout_index >= ${#layout_mapping[@]})); then
  printf '%s\n' "Invalid active keyboard layout index: $layout_index" >&2
  exit 1
fi

current_layout="${layout_mapping[$layout_index]}"
current_variant=''
if ((layout_index < ${#variant_mapping[@]})); then
  current_variant="${variant_mapping[$layout_index]}"
fi

case "${1-}" in
  status)
    printf '%s\n' "$current_layout${current_variant:+($current_variant)}"
    ;;
  switch)
    layout_count=${#layout_mapping[@]}
    next_index=$(( (layout_index + 1) % layout_count ))
    new_layout="${layout_mapping[$next_index]}"
    new_variant=''
    if ((next_index < ${#variant_mapping[@]})); then
      new_variant="${variant_mapping[$next_index]}"
    fi

    printf 'Current layout: %s%s\n' "$current_layout" "${current_variant:+($current_variant)}"
    printf 'Number of layouts: %d\n' "$layout_count"
    printf 'Next layout: %s%s\n' "$new_layout" "${new_variant:+($new_variant)}"

    error_found=0
    for name in "${keyboard_names[@]}"; do
      if is_ignored "$name"; then
        printf 'Skipping ignored device: %s\n' "$name"
        continue
      fi

      printf 'Switching layout for %s to %d...\n' "$name" "$next_index"
      if hyprctl switchxkblayout "$name" "$next_index"; then
        continue
      fi

      printf 'Error while switching layout for %s.\n' "$name" >&2
      error_found=1
    done

    if ((error_found)); then
      notify-send -u low -t 2000 'kb_layout' 'Layout change failed' 2>/dev/null || true
      exit 1
    fi

    notify-send -u low -i "$notif_icon" "kb_layout: $new_layout${new_variant:+($new_variant)}" 2>/dev/null || true
    ;;
  *)
    printf 'Usage: %s {status|switch}\n' "$0" >&2
    exit 2
    ;;
esac

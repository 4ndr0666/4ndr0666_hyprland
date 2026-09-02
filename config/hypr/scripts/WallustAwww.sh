#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# Wallust: derive colors from the current wallpaper and update templates
# Usage: WallustAwww.sh [absolute_path_to_wallpaper]

set -Eeuo pipefail

passed_path="${1:-}"
cache_dir="$HOME/.cache/awww/"
rofi_link="$HOME/.config/rofi/.current_wallpaper"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
waybar_colors="$HOME/.config/waybar/wallust/colors-waybar.css"
rofi_colors="$HOME/.config/rofi/wallust/colors-rofi.rasi"

read_cached_wallpaper() {
  local cache_file="$1"
  if [[ -f "$cache_file" ]]; then
    awk 'NF && $0 !~ /^filter/ {print; exit}' "$cache_file"
  fi
}

read_wallpaper_from_query() {
  local monitor="$1"
  awww query | awk -v mon="$monitor" '
    /^Monitor/ {
      cur=$2
      gsub(":", "", cur)
    }
    /image:/ && cur==mon {
      sub(/^.*image: /,"")
      print
      exit
    }
  '
}

get_focused_monitor() {
  if command -v jq >/dev/null 2>&1; then
    hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'
  else
    hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}'
  fi
}

wallpaper_path=""
if [[ -n "$passed_path" ]]; then
  [[ -f "$passed_path" ]] || {
    printf '%s\n' "[ERROR] Wallpaper path does not exist: $passed_path" >&2
    exit 1
  }
  wallpaper_path="$passed_path"
else
  current_monitor="$(get_focused_monitor)"
  [[ -n "$current_monitor" ]] || {
    printf '%s\n' '[ERROR] Unable to determine the focused monitor.' >&2
    exit 1
  }
  cache_file="$cache_dir$current_monitor"

  for _ in {1..10}; do
    if [[ -f "$cache_file" ]]; then
      break
    fi
    sleep 0.1
done

  if [[ -f "$cache_file" ]]; then
    wallpaper_path="$(read_cached_wallpaper "$cache_file")"
  fi

  if [[ -z "$wallpaper_path" ]]; then
    wallpaper_path="$(read_wallpaper_from_query "$current_monitor")"
  fi
fi

[[ -n "$wallpaper_path" && -f "$wallpaper_path" ]] || {
  printf '%s\n' '[ERROR] Unable to resolve the current wallpaper.' >&2
  exit 1
}

wallpaper_path="$(realpath -- "$wallpaper_path")"

mkdir -p -- "$(dirname -- "$rofi_link")" "$(dirname -- "$wallpaper_current")"
ln -sfn -- "$wallpaper_path" "$rofi_link"
cp -f -- "$wallpaper_path" "$wallpaper_current"

printf '%s\n' "[INFO] Generating Wallust palette from: $wallpaper_path"
if ! command -v wallust >/dev/null 2>&1; then
  printf '%s\n' '[ERROR] wallust is not installed.' >&2
  exit 127
fi

if ! wallust run -s "$wallpaper_path"; then
  printf '%s\n' '[ERROR] Wallust failed; consumers will not be reloaded.' >&2
  exit 1
fi

validate_target() {
  local file="$1"
  [[ -s "$file" ]] || {
    printf '%s\n' "[ERROR] Wallust target is missing or empty: $file" >&2
    return 1
  }
}

validate_target "$waybar_colors"
validate_target "$rofi_colors"

grep -Eq '^@define-color color(0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15) #[0-9A-Fa-f]{6};$' "$waybar_colors" || {
  printf '%s\n' '[ERROR] Wallust Waybar palette failed structural validation.' >&2
  exit 1
}

grep -Eq '^\s*color12:\s*#[0-9A-Fa-f]{6};$' "$rofi_colors" || {
  printf '%s\n' '[ERROR] Wallust Rofi palette failed structural validation.' >&2
  exit 1
}

printf '%s\n' '[OK] Wallust generated and validated the canonical Waybar/Rofi palettes.'

if command -v waybar-msg >/dev/null 2>&1; then
  waybar-msg cmd reload >/dev/null 2>&1 || {
    printf '%s\n' '[ERROR] Waybar reload failed.' >&2
    exit 1
  }
elif pidof waybar >/dev/null 2>&1; then
  killall -SIGUSR2 waybar >/dev/null 2>&1 || {
    printf '%s\n' '[ERROR] Waybar reload signal failed.' >&2
    exit 1
  }
else
  printf '%s\n' '[ERROR] Waybar is not running; palette generation completed but no consumer was reloaded.' >&2
  exit 1
fi

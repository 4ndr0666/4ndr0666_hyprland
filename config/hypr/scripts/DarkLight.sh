#!/usr/bin/env bash
# === 4ndr0666 === #
# Toggle the desktop between the repository's Dark and Light profiles.
set -Eeuo pipefail

readonly HOME_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly SCRIPTSDIR="$HOME_CONFIG/hypr/scripts"
readonly WALLPAPER_ROOT="$HOME/Wallpapers/Dynamic-Wallpapers"
readonly DARK_WALLPAPERS="$WALLPAPER_ROOT/Dark"
readonly LIGHT_WALLPAPERS="$WALLPAPER_ROOT/Light"
readonly THEME_MODE_FILE="$HOME/.cache/.theme_mode"
readonly NOTIFICATION_ICON="$HOME_CONFIG/swaync/images/bell.png"
readonly WALLUST_CONFIG="$HOME_CONFIG/wallust/wallust.toml"
readonly KITTY_CONFIG="$HOME_CONFIG/kitty/kitty.conf"
readonly QT5_CONFIG="$HOME_CONFIG/qt5ct/qt5ct.conf"
readonly QT6_CONFIG="$HOME_CONFIG/qt6ct/qt6ct.conf"

readonly DARK_PALETTE="dark16"
readonly LIGHT_PALETTE="light16"
readonly DARK_QT5="$HOME_CONFIG/qt5ct/colors/Catppuccin-Mocha.conf"
readonly LIGHT_QT5="$HOME_CONFIG/qt5ct/colors/Catppuccin-Latte.conf"
readonly DARK_QT6="$HOME_CONFIG/qt6ct/colors/Catppuccin-Mocha.conf"
readonly LIGHT_QT6="$HOME_CONFIG/qt6ct/colors/Catppuccin-Latte.conf"

mkdir -p "$(dirname "$THEME_MODE_FILE")"
current_mode="$(cat "$THEME_MODE_FILE" 2>/dev/null || printf '%s' Light)"
case "$current_mode" in
  Light) next_mode=Dark; wallpaper_root="$DARK_WALLPAPERS" ;;
  Dark) next_mode=Light; wallpaper_root="$LIGHT_WALLPAPERS" ;;
  *) printf '%s\n' '[ERROR] Invalid theme mode state.' >&2; exit 1 ;;
esac

if [[ "$next_mode" == Dark ]]; then
  palette="$DARK_PALETTE"
  qt5_color="$DARK_QT5"
  qt6_color="$DARK_QT6"
  kvantum_theme='catppuccin-mocha-blue'
  kitty_foreground='#dddddd'
  kitty_background='#000000'
  kitty_cursor='#dddddd'
else
  palette="$LIGHT_PALETTE"
  qt5_color="$LIGHT_QT5"
  qt6_color="$LIGHT_QT6"
  kvantum_theme='catppuccin-latte-blue'
  kitty_foreground='#000000'
  kitty_background='#dddddd'
  kitty_cursor='#000000'
fi

[[ -f "$WALLUST_CONFIG" ]] || { printf '%s\n' "[ERROR] Missing Wallust configuration: $WALLUST_CONFIG" >&2; exit 1; }
[[ -d "$wallpaper_root" ]] || { printf '%s\n' "[ERROR] Missing wallpaper directory: $wallpaper_root" >&2; exit 1; }

sed -i -E "s|^palette[[:space:]]*=.*$|palette = \"$palette\"|" "$WALLUST_CONFIG"

set_waybar_style() {
  local theme="$1"
  local styles="$HOME_CONFIG/waybar/style"
  local link="$HOME_CONFIG/waybar/style.css"
  local -a candidates=()
  local style base

  while IFS= read -r -d '' style; do
    base="$(basename "$style")"
    case "$base" in
      "[$theme]"*.css) candidates+=("$style") ;;
    esac
  done < <(find -L "$styles" -maxdepth 1 -type f -name '*.css' -print0)

  ((${#candidates[@]})) || { printf '%s\n' "[ERROR] No Waybar style exists for $theme mode." >&2; return 1; }
  ln -sfn -- "${candidates[RANDOM % ${#candidates[@]}]}" "$link"
}

select_random_wallpaper() {
  find -L "$1" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 \
    | shuf -z -n 1 | tr -d '\0'
}

notify_user() {
  notify-send -u low -i "$NOTIFICATION_ICON" 'Switching to' "$next_mode mode"
}

set_kitty_colors() {
  [[ -f "$KITTY_CONFIG" ]] || return 0
  sed -i -E "s|^foreground[[:space:]].*$|foreground $kitty_foreground|" "$KITTY_CONFIG"
  sed -i -E "s|^background[[:space:]].*$|background $kitty_background|" "$KITTY_CONFIG"
  sed -i -E "s|^cursor[[:space:]].*$|cursor $kitty_cursor|" "$KITTY_CONFIG"
  pkill -SIGUSR1 kitty 2>/dev/null || true
}

set_qt_colors() {
  [[ -f "$QT5_CONFIG" ]] && sed -i -E "s|^color_scheme_path=.*$|color_scheme_path=$qt5_color|" "$QT5_CONFIG"
  [[ -f "$QT6_CONFIG" ]] && sed -i -E "s|^color_scheme_path=.*$|color_scheme_path=$qt6_color|" "$QT6_CONFIG"
  if command -v kvantummanager >/dev/null 2>&1; then
    if [[ -f "$HOME_CONFIG/Kvantum/$kvantum_theme/$kvantum_theme.kvconfig" ||
          -f "/usr/share/Kvantum/$kvantum_theme/$kvantum_theme.kvconfig" ]]; then
      kvantummanager --set "$kvantum_theme"
    else
      printf '[WARN] Kvantum theme %s is unavailable; preserving selected theme.\n' "$kvantum_theme" >&2
    fi
  fi
}

set_custom_gtk_theme() {
  local mode="$1"
  local theme_dir="$HOME/.themes"
  local icon_dir="$HOME/.icons"
  local schema='org.gnome.desktop.interface'
  local theme_setting='gtk-theme'
  local icon_setting='icon-theme'
  local color_setting='color-scheme'
  local keyword='*Light*'
  [[ "$mode" == Dark ]] && keyword='*Dark*'

  command -v gsettings >/dev/null 2>&1 || return 0
  if [[ "$mode" == Dark ]]; then
    gsettings set "$schema" "$color_setting" prefer-dark
  else
    gsettings set "$schema" "$color_setting" prefer-light
  fi

  local -a themes=() icons=()
  local item
  local root
  for root in "$theme_dir" "${XDG_DATA_HOME:-$HOME/.local/share}/themes" /usr/share/themes; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' item; do themes+=("$(basename "$item")"); done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -iname "$keyword" -print0)
  done
  for root in "$icon_dir" "${XDG_DATA_HOME:-$HOME/.local/share}/icons" /usr/share/icons; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' item; do icons+=("$(basename "$item")"); done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -iname "$keyword" -print0)
  done

  if ((${#themes[@]})); then
    gsettings set "$schema" "$theme_setting" "${themes[RANDOM % ${#themes[@]}]}"
  fi
  if ((${#icons[@]})); then
    local selected_icon="${icons[RANDOM % ${#icons[@]}]}"
    gsettings set "$schema" "$icon_setting" "$selected_icon"
    [[ -f "$QT5_CONFIG" ]] && sed -i -E "s|^icon_theme=.*$|icon_theme=$selected_icon|" "$QT5_CONFIG"
    [[ -f "$QT6_CONFIG" ]] && sed -i -E "s|^icon_theme=.*$|icon_theme=$selected_icon|" "$QT6_CONFIG"
  fi
  return 0
}

awww query >/dev/null 2>&1 || {
  printf '%s\n' '[ERROR] awww-daemon is not ready; refusing to start a second owner.' >&2
  exit 1
}
wallpaper="$(select_random_wallpaper "$wallpaper_root")"
[[ -n "$wallpaper" ]] || { printf '%s\n' '[ERROR] No suitable wallpaper found.' >&2; exit 1; }

awww img --transition-bezier .43,1.19,1,.4 --transition-fps 60 --transition-type grow \
  --transition-pos 0.925,0.977 --transition-duration 2 -- "$wallpaper"
"$SCRIPTSDIR/WallustAwww.sh" "$wallpaper"
set_waybar_style "$next_mode"
set_kitty_colors
set_qt_colors
set_custom_gtk_theme "$next_mode"
printf '%s\n' "$next_mode" >"$THEME_MODE_FILE"
notify_user

"$SCRIPTSDIR/Refresh.sh"
notify-send -u low -i "$NOTIFICATION_ICON" 'Themes switched to:' "$next_mode Mode"

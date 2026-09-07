#!/usr/bin/env bash
set -Eeuo pipefail

# SPDX-FileCopyrightText: 2025-present Ahum Maitra theahummaitra@gmail.com
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Repository url : https://github.com/TheAhumMaitra/cautious-waddle

have_notify() {
  command -v notify-send >/dev/null 2>&1
}

prompt_status=0
choice=''
if choice="$(wallust theme list | sed -e '1d' -e 's/^- //' | rofi -dmenu -i -p 'Select Global Theme')"; then
  :
else
  prompt_status=$?
fi

case "$prompt_status" in
  0) ;;
  1) exit 0 ;;
  *) printf 'Theme selection failed with status %d.\n' "$prompt_status" >&2; exit "$prompt_status" ;;
esac

[[ -n "$choice" ]] || exit 0

if ! wallust theme -- "$choice"; then
  have_notify && notify-send -u critical -a ThemeChanger \
    -h string:x-dunst-stack-tag:themechanger \
    "Failed to apply theme" "${choice}"
  printf 'Failed to apply theme: %s\n' "$choice" >&2
  exit 1
fi

have_notify && notify-send -a ThemeChanger \
  -h string:x-dunst-stack-tag:themechanger \
  "Global theme changed" "Selected: ${choice}"

# Wallust writes these targets synchronously; treat missing or empty outputs as an incomplete transaction.
mkdir -p "$HOME/.config/ghostty"
targets=(
  "$HOME/.config/waybar/wallust/colors-waybar.css"
  "$HOME/.config/rofi/wallust/colors-rofi.rasi"
  "$HOME/.config/kitty/kitty-themes/01-Wallust.conf"
  "$HOME/.config/hypr/wallust/wallust-hyprland.conf"
  "$HOME/.config/ghostty/wallust.conf"
)

for target in "${targets[@]}"; do
  [[ -s "$target" ]] || {
    printf 'Theme transaction incomplete; missing or empty target: %s\n' "$target" >&2
    exit 1
  }
done

# Normalize Ghostty palette syntax in case upstream templates or older targets used ':'.
ghostty_conf="$HOME/.config/ghostty/wallust.conf"
sed -i -E 's/^(\s*palette\s*=\s*)([0-9]{1,2}):/\1\2=/' "$ghostty_conf"

# Normalize Rofi selection colors to use the palette accent (color12, falling back to color13).
rofi_colors="$HOME/.config/rofi/wallust/colors-rofi.rasi"
accent_hex=''
accent_hex="$(sed -n 's/^\s*color12:\s*\(#[0-9A-Fa-f]\{6\}\).*/\1/p' "$rofi_colors" | head -n1)"
if [[ -z "$accent_hex" ]]; then
  accent_hex="$(sed -n 's/^\s*color13:\s*\(#[0-9A-Fa-f]\{6\}\).*/\1/p' "$rofi_colors" | head -n1)"
fi

if [[ -n "$accent_hex" ]]; then
  rofi_tmp="$(mktemp "$(dirname -- "$rofi_colors")/.colors-rofi.XXXXXX")"
  cleanup_rofi_tmp() {
    rm -f -- "$rofi_tmp"
  }
  trap cleanup_rofi_tmp RETURN
  sed -E \
    -e "s|^(\s*selected-normal-background:\s*).*$|\1$accent_hex;|" \
    -e "s|^(\s*selected-active-background:\s*).*$|\1$accent_hex;|" \
    -e "s|^(\s*selected-urgent-background:\s*).*$|\1$accent_hex;|" \
    -e 's|^(\s*selected-normal-foreground:\s*).*$|\1#000000;|' \
    -e 's|^(\s*selected-active-foreground:\s*).*$|\1#000000;|' \
    -e 's|^(\s*selected-urgent-foreground:\s*).*$|\1#000000;|' \
    "$rofi_colors" >"$rofi_tmp"
  mv -f -- "$rofi_tmp" "$rofi_colors"
  rofi_tmp=''
  trap - RETURN
fi

# Reload Hyprland so new border colors take effect.
if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload
fi

# Refresh bars/menus after generated files are ready.
if [[ -x "$HOME/.config/hypr/scripts/Refresh.sh" ]]; then
  "$HOME/.config/hypr/scripts/Refresh.sh"
elif command -v waybar-msg >/dev/null 2>&1; then
  waybar-msg cmd reload
else
  if pkill -SIGUSR2 waybar 2>/dev/null; then
    :
  else
    rc=$?
    ((rc == 1)) || exit "$rc"
  fi
fi

# Ask running terminals to reload their generated configuration; absence is not an error.
if pkill -SIGUSR1 -x kitty 2>/dev/null; then
  :
else
  rc=$?
  ((rc == 1)) || exit "$rc"
fi

if pkill -SIGUSR2 -x ghostty 2>/dev/null; then
  :
else
  rc=$?
  ((rc == 1)) || exit "$rc"
fi

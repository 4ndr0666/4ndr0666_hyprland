#!/usr/bin/env bash
##################################################################
#                                                                #
#                  TAK_0'S Per-Window-Switch                     #
#                                                                #
#  Just a little script that I made to switch keyboard layouts   #
#       per-window instead of global switching for the more      #
#                 smooth and comfortable workflow.               #
#                                                                #
##################################################################
# This is for changing kb_layouts. Set kb_layouts in $HOME/.config/hypr/UserConfigs/UserSettings.lua
# (falls back to $HOME/.config/hypr/configs/SystemSettings.lua).

MAP_FILE="$HOME/.cache/kb_layout_per_window"
USER_CFG_FILE="$HOME/.config/hypr/UserConfigs/UserSettings.lua"
SYS_CFG_FILE="$HOME/.config/hypr/configs/SystemSettings.lua"
ICON="$HOME/.config/swaync/images/ja.png"
SCRIPT_NAME="$(basename "$0")"

mkdir -p "$(dirname "$MAP_FILE")"
touch "$MAP_FILE"

CFG_FILE="$SYS_CFG_FILE"
if [[ -f "$USER_CFG_FILE" ]] && grep -Eq '^[[:space:]]*kb_layout[[:space:]]*=' "$USER_CFG_FILE"; then
  CFG_FILE="$USER_CFG_FILE"
fi

if [[ ! -f "$CFG_FILE" ]] || ! grep -q 'kb_layout' "$CFG_FILE"; then
  echo "Error: cannot find kb_layout in $CFG_FILE" >&2
  exit 1
fi
kb_layouts=($(grep 'kb_layout' "$CFG_FILE" | tail -n 1 | cut -d '=' -f2 | sed -E 's/--.*$//' | tr -d '[:space:]"'\''' | sed 's/,$//' | sed 's/}.*$//' | tr ',' ' '))
count=${#kb_layouts[@]}

# Get current active window ID
get_win() {
  hyprctl activewindow -j | jq -r '.address // .id'
}

# Get available keyboards
get_keyboards() {
  hyprctl devices -j | jq -r '.keyboards[].name'
}

# Save window-specific layout
save_map() {
  local W=$1 L=$2
  grep -v "^${W}:" "$MAP_FILE" > "$MAP_FILE.tmp" || true
  echo "${W}:${L}" >> "$MAP_FILE.tmp"
  mv "$MAP_FILE.tmp" "$MAP_FILE"
}

# Load layout for window (fallback to default)
load_map() {
  local W=$1
  local E
  E=$(grep "^${W}:" "$MAP_FILE" || true)
  [[ -n "$E" ]] && echo "${E#*:}" || echo "${kb_layouts[0]}"
}

# Switch layout for all keyboards to layout index
do_switch() {
  local IDX=$1
  for kb in $(get_keyboards); do
    hyprctl switchxkblayout "$kb" "$IDX" 2>/dev/null
  done
}

# Toggle layout for current window only
cmd_toggle() {
  local W=$(get_win)
  [[ -z "$W" || "$W" == "null" ]] && return
  local CUR=$(load_map "$W")
  local i=0 NEXT
  for idx in "${!kb_layouts[@]}"; do
    if [[ "${kb_layouts[idx]}" == "$CUR" ]]; then
      i=$idx
      break
    fi
  done
  NEXT=$(( (i+1) % count ))
  do_switch "$NEXT"
  save_map "$W" "${kb_layouts[NEXT]}"
  notify-send -u low -i "$ICON" "kb_layout: ${kb_layouts[NEXT]}"
}

# Restore layout on focus
cmd_restore() {
  local W=$(get_win)
  [[ -z "$W" || "$W" == "null" ]] && return
  local LAY=$(load_map "$W")
  for idx in "${!kb_layouts[@]}"; do
    if [[ "${kb_layouts[idx]}" == "$LAY" ]]; then
      do_switch "$idx"
      break
    fi
  done
}

# Listen to focus events and restore window-specific layouts
subscribe() {
  local SOCKET2="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
  [[ -S "$SOCKET2" ]] || { echo "Error: Hyprland socket not found." >&2; exit 1; }

  socat -u UNIX-CONNECT:"$SOCKET2" - | while read -r line; do
    [[ "$line" =~ ^activewindow ]] && cmd_restore
  done
}

if [[ "${1:-}" == "--listener" ]]; then
  subscribe
  exit 0
fi

# Ensure only one listener
if ! pgrep -f "$SCRIPT_NAME.*--listener" >/dev/null 2>&1; then
  "$0" --listener >/dev/null 2>&1 &
fi

# CLI
case "${1:-}" in
  --init|restore) cmd_restore ;;
  toggle|"") cmd_toggle ;;
  *) echo "Usage: $SCRIPT_NAME [toggle|--init|restore|--listener]" >&2; exit 1 ;;
esac

#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##
# RofiBeats - unified, dynamic UI (add, remove, manage, play)

mDIR="$HOME/Music/"
iDIR="$HOME/.config/swaync/icons"
rofi_theme="$HOME/.config/rofi/config-rofi-Beats.rasi"
rofi_theme_menu="$HOME/.config/rofi/config-rofi-Beats-menu.rasi"
music_list="$HOME/.config/rofi/online_music.list"

mkdir -p "$(dirname "$music_list")"
[[ -f "$music_list" ]] || touch "$music_list"

notification() {
  notify-send -u normal -i "$iDIR/music.png" "$@"
}

music_playing() { pgrep -x "mpv" >/dev/null; }

stop_music() {
  local mpv_pids pid cmdline status=0
  mpv_pids="$(pgrep -x mpv || true)"
  [[ -n "$mpv_pids" ]] || return 0

  while read -r pid; do
    [[ -n "$pid" ]] || continue
    cmdline="$(ps -p "$pid" -o args= 2>/dev/null || true)"
    case "$cmdline" in
      *unique-wallpaper-process*) continue ;;
    esac

    if ! kill -TERM "$pid" 2>/dev/null; then
      if kill -0 "$pid" 2>/dev/null; then
        printf '[ERROR] failed to terminate mpv process %s\n' "$pid" >&2
        status=1
      fi
      continue
    fi

    for _ in {1..10}; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.05
    done
    if kill -0 "$pid" 2>/dev/null; then
      if ! kill -KILL "$pid" 2>/dev/null && kill -0 "$pid" 2>/dev/null; then
        printf '[ERROR] failed to terminate mpv process %s after TERM\n' "$pid" >&2
        status=1
      fi
    fi
  done <<< "$mpv_pids"

  ((status == 0)) && notification "Music stopped"
  return "$status"
}

populate_local_music() {
  local_music=()
  filenames=()
  while IFS= read -r file; do
    local_music+=("$file")
    filenames+=("$(basename "$file")")
  done < <(find -L "$mDIR" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.ogg" -o -iname "*.mp4" \))
}

play_local_music() {
  populate_local_music
  choice=$(printf "%s\n" "${filenames[@]}" | rofi -i -dmenu -config "$rofi_theme" \
    -theme-str 'entry { placeholder: "🎵 Choose Local Music"; }')
  [[ -z "$choice" ]] && exit 1
  for ((i = 0; i < "${#filenames[@]}"; ++i)); do
    if [ "${filenames[$i]}" = "$choice" ]; then
      music_playing && stop_music
      notification "Now Playing:" "$choice"
      mpv --no-video --playlist-start="$i" --loop-playlist "${local_music[@]}"
      break
    fi
  done
}

shuffle_local_music() {
  music_playing && stop_music
  notification "Shuffle Play local music"
  mpv --no-video --shuffle --loop-playlist "$mDIR"
}

play_online_music() {
  if [ ! -s "$music_list" ]; then
    notify-send -u low -i "$iDIR/music.png" "No online music found" "Add some with Manage Music"
    exit 0
  fi
  choice=$(awk -F'|' '{print $1}' "$music_list" | sort | rofi -i -dmenu -config "$rofi_theme" \
    -theme-str 'entry { placeholder: "🌐 Choose Online Station"; }')
  [[ -z "$choice" ]] && exit 1
  link=$(awk -F'|' -v name="$choice" '$1 == name {print $2; exit}' "$music_list")
  [[ -z "$link" ]] && {
    notify-send -u low -i "$iDIR/music.png" "URL not found for" "$choice"
    exit 1
  }
  music_playing && stop_music
  notification "Now Playing:" "$choice"
  mpv --no-video --shuffle "$link"
}

manage_music() {
  local entry tmp
  sub_choice=$(printf "Add Music\nRemove Music\nView List" | rofi -dmenu \
    -config "$rofi_theme_menu" \
    -theme-str 'entry { placeholder: "🛠️ Manage Music List"; }')

  case "$sub_choice" in
  "Add Music")
    name=$(rofi -dmenu -lines 0 -config "$rofi_theme_menu" \
      -theme-str 'entry { placeholder: "🎼 Enter Music Title"; }')
    [[ -z "$name" ]] && return
    url=$(rofi -dmenu -lines 0 -config "$rofi_theme_menu" \
      -theme-str 'entry { placeholder: "🔗 Enter Music URL"; }')
    [[ -z "$url" ]] && return
    printf '%s\n' "$name|$url" >>"$music_list"
    notification "Added" "$name"
    ;;
  "Remove Music")
    entry=$(awk -F'|' '{print $1}' "$music_list" | rofi -dmenu -config "$rofi_theme_menu" \
      -theme-str 'entry { placeholder: "🗑️ Select Music to Remove"; }')
    [[ -z "$entry" ]] && return
    tmp="$(mktemp "${music_list}.tmp.XXXXXX")"
    awk -F'|' -v entry="$entry" '$1 != entry' "$music_list" >"$tmp" || { rm -f -- "$tmp"; return 1; }
    mv -- "$tmp" "$music_list"
    notification "Removed" "$entry"
    ;;
  "View List")
    awk -F'|' '{print $1}' "$music_list" | rofi -dmenu -config "$rofi_theme_menu" \
      -theme-str 'entry { placeholder: "📜 Online Music List"; }' >/dev/null
    ;;
  esac
}

user_choice=$(printf "%s\n" \
  "Play from Online Stations" \
  "Play from Music directory" \
  "Shuffle Play from Music directory" \
  "Stop RofiBeats" \
  "Manage Music List" |
  rofi -dmenu -config "$rofi_theme_menu" \
    -theme-str 'entry { placeholder: "🎧 RofiBeats Menu"; }')

case "$user_choice" in
"Play from Online Stations") play_online_music ;;
"Play from Music directory") play_local_music ;;
"Shuffle Play from Music directory") shuffle_local_music ;;
"Stop RofiBeats") music_playing && stop_music ;;
"Manage Music List") manage_music ;;
esac

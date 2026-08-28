#!/usr/bin/env bash

# GDK BACKEND. Force wayland for Hyprland compatibility
BACKEND=wayland

# Check if rofi or yad is running and kill them if they are
if pidof rofi > /dev/null; then
  pkill rofi
fi

if pidof yad > /dev/null; then
  pkill yad
fi

# ==============================================================================
# DATA PAYLOAD: Array implementation guarantees syntax integrity and prevents
# line-continuation (\) breaking during copy/paste operations.
# ==============================================================================
declare -a KEYBINDS=(
	" SHIFT K" "Search Keybinds" "(Rofi)"
	" SHIFT N" "Notifications" "(Mako)"
	" A" "Desktop Overview" "(Quickshell)"
	" SHIFT A" "Hyprland Animations" "(Rofi)"
	" CTRL R" "Rofi Themes" "(Rofi)"
	" CTRL Shift R" "Rofi Themes v2" "(Rofi)"
	" T" "Global theme switcher" "(Rofi)"
	" W" "Choose wallpaper" "(Wallpaper Menu)"
	" SHIFT W" "Choose wallpaper effects" "(Imagemagick + Swww)"
	"CTRL ALT W" "Random wallpaper" "(Swww)"
	" SHIFT E" "Hyprland Settings Menu" ""
	"" "" ""
	"<span weight='bold'>                        ===⦑     💀Ψ•-⦑  GENERAL  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" B" "Launch Browser" "(Brave-Beta)"
	" D" "Application Launcher" "(Rofi-wayland)"
	" F" "Open File Manager" "(Thunar)"
	" N" "Network Manager" "(RofiNetwork.sh)"
	" S" "Yandex Web Search" "(Rofi)"
	" E" "Text Editor" "(Nvim)"
	" F1" "Clipboard Manager" "(ClipManager.sh)"
	" P" "Color Picker" "(Colorpicker.sh)"
	" SHIFT M" "Online Music" "(RofiBeats.sh)"
	" ALT C" "Calculator" "(RofiCalc.sh)"
	" ALT E" "Emoticons" "(Emojis)"
	" SHIFT N" "Night Light" "(Hypersunset.sh)"
	" ALT_L SHIFT_L" "Keyboard Switch" "(KeyboardLayout.sh)"
	" X" "Power-menu" "(wlogout)"
	"CTRL ALT L" "Screen Lock" "(Hyprlock)"
	"CTRL ALT Del" "Kill Hyprland" "(Immediate Exit)"
	"" "" ""
	"<span weight='bold'>                         ===⦑     💀Ψ•-⦑  WAYBAR  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" CTRL ALT B" "Waybar Toggle" "(On/Off)"
	" CTRL B" "Waybar Styles" "(Menu)"
	" ALT B" "Waybar Layouts" "(Menu)"
	" ALT R" "Waybar Refresh" "(Restart)"
	"" "" ""
	"<span weight='bold'>                      ===⦑     💀Ψ•-⦑  TERMINALS  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" ENTER" "Terminal" "(Kitty)"
	" ALT ENTER" "Terminal" "(St)"
	" CTRL ENTER" "Terminal" "(Alacritty)"
	" SHIFT ENTER" "DropDown Terminal" "(Kitty)"
	"" "" ""
	"<span weight='bold'>                    ===⦑     💀Ψ•-⦑  SCREENSHOTS  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" PRINT" "screenshot" "(grim)"
	" SHIFT PRINT" "screenshot region" "(grim + slurp)"
	" SHIFT S" "Screenshot Menu" "(RofiScreenshot.sh)"
	" CTRL PRINT" "screenshot timer 5 secs " "(grim)"
	" CTRL SHIFT PRINT" "screenshot timer 10 secs " "(grim)"
	"ALT PRINT" "Screenshot active window" "active window only"
	"" "" ""
	"<span weight='bold'>                        ===⦑     💀Ψ•-⦑  WINDOWS  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" CTRL S" "Window Switcher" ""
	"ALT TAB" "Cycle Next Window" ""
	"ALT TAB" "Active To Top" ""
	" Q" "Close Window" ""
	" SHIFT Q" "Kill Window" ""
	" SHIFT F" "Fullscreen" ""
	" CTRL F" "Fake Fullscreen Pane 1" ""
	" SPACE" "Float Current Window" ""
	" ALT SPACE" "Float All Windows" ""
	" ALT MOUSE_WHEEL" "Desktop Zoom" ""
	" ALT O" "Adjust Window Blur" ""
	" CTRL O" "Make Active Window Opaque" ""
	"" "" ""
	"<span weight='bold'>                        ===⦑     💀Ψ•-⦑  LAYOUTS  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" ALT L" "Change Window Layout" "(Master/Dwindle)"
	" SHIFT I" "Remove Master Window" "-"
	" I" "Add Master Window" "+"
	" CTRL ENTER" "Swap Master Window" ""
	" SHIFT I" "Toggle Split" "Dwindle"
	" I" "Toggle Pseudo" "Dwindle"
	" M" "Set Split Ratio" "All Layouts"
	"" "" ""
	"<span weight='bold'>                ===⦑     💀Ψ•-⦑  CUSTOM KEYBINDS  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" F2" "File Manager" "Yazi"
	" F3" "Text Editor" "Micro"
	" SHIFT F3" "Text Editor" "Neovim"
	" F5" "Media Player" "Play With MPV"
	" F6" "Media Editor" "Vidcut"
	" SHIFT F6" "Media Editor" "Losslesscut"
	" F7" "Downloader" "Jdownloader"
	" SHIFT F7" "Downloader" "Dmenuhandler"
	" F8" "Service Manager" "4ndr0service"
	" SHIFT F8" "Kill Hanging" "Trigger_oom.sh"
	" F9" "Torrent Manager" "Torwrap.sh"
	" SHIFT F9" "Google Dorks" "Dorkmaster.py"
	" F10" "Media Player" "MPV Network Profile"
	" SHIFT F10" "Media Manager" "Wofi_media.sh"
	" F12" "Screenrecorder" "Dmenurecord"
	"" "" ""
)

# ==============================================================================
# UI INITIALIZATION & EXECUTION
# ==============================================================================
# Launch yad, expand geometry to absolute fullscreen via --fullscreen
yad_output=$(GDK_BACKEND=$BACKEND yad \
	--fullscreen \
	--borders=15 \
	--title="4NDR0666OS Core Directives" \
	--window-icon="system-run" \
	--no-buttons \
	--list \
	--search-column=2 \
	--separator='|' \
	--column="<span foreground='#e06c75' weight='bold'>Keybind</span>" \
	--column="<span foreground='#61afef' weight='bold'>Operation</span>" \
	--column="<span foreground='#98c379' weight='bold'>Target / Tool</span>" \
	--timeout-indicator=bottom \
	"${KEYBINDS[@]}")

# ==============================================================================
# ACTIVE EXECUTION ROUTER (C2 LINK)
# ==============================================================================
# Intercepts the pipe and executes target binaries/scripts
if [ -n "$yad_output" ]; then
	# Parse the exact node selected by the operator.
	# The sed command strips HTML Pango markup from headers if accidentally clicked.
	selected_key=$(echo "$yad_output" | awk -F'|' '{print $1}' | sed 's/<[^>]*>//g')
	selected_op=$(echo "$yad_output" | awk -F'|' '{print $2}')
	selected_raw_cmd=$(echo "$yad_output" | awk -F'|' '{print $3}')

	# Strip parentheses and excess whitespace from the target column to create a clean execution string
	clean_cmd=$(echo "$selected_raw_cmd" | tr -d '()' | xargs)

	# Nullify empty selections or aesthetic spacer rows
	if [[ -n "$selected_key" && ! "$selected_key" =~ "---" && "$selected_key" != " " ]]; then

		# Log the operation initiation
		notify-send -u normal -a "4NDR0666OS" "Execution Sequence" "Target: $clean_cmd\nInitiated via: $selected_key"

		# Execution Switch: Map the sanitized command string to actual system operations
		case "$clean_cmd" in
		"Rofi" | "Rofi-wayland")
			rofi -show drun &
			;;
		"Mako")
			mako &
			;;
		"Quickshell")
			quickshell &
			;;
		"Wallpaper Menu")
			# Fallback to Waypaper or equivalent wallpaper daemon UI
			waypaper &
			;;
		"Kitty")
			kitty &
			;;
		"St")
			st &
			;;
		"Alacritty")
			alacritty &
			;;
		"Brave-Beta")
			brave-browser-beta &
			;;
		"Thunar")
			thunar &
			;;
		"Nvim" | "Neovim")
			kitty -e nvim &
			;;
		"Micro")
			kitty -e micro &
			;;
		"Yazi")
			kitty -e yazi &
			;;
		"grim")
			grim ~/Pictures/Screenshots/$(date +'%Y-%m-%d+%H:%M:%S').png &
			;;
		"grim + slurp")
			grim -g "$(slurp)" ~/Pictures/Screenshots/$(date +'%Y-%m-%d+%H:%M:%S').png &
			;;
		"wlogout")
			wlogout -b 5 -c 0 -r 0 -m 400 &
			;;
		"Hyprlock")
			hyprlock &
			;;
		"Immediate Exit")
			hyprctl dispatch exit
			;;
		"Play With MPV" | "MPV Network Profile")
			kitty -e mpv --player-operation-mode=pseudo-gui &
			;;
		"Vidcut")
			vidcut &
			;;
		"Losslesscut")
			losslesscut &
			;;
		"Jdownloader")
			jdownloader &
			;;
		*.sh | *.py)
			# Dynamic Script Handler: Assumes tools exist in $PATH and require a terminal wrapper
			kitty -e "$clean_cmd" &
			;;
		"")
			# Handle layout/WM actions that have no explicit tool listed by copying keybind
			echo -n "$selected_key" | wl-copy
			notify-send -u low -a "4NDR0666OS" "Clipboard Injected" "Keybind $selected_key copied (No direct exec mapped)."
			;;
		*)
			# Fallback for complex unmapped targets - Inject to clipboard
			echo -n "$selected_key" | wl-copy
			notify-send -u low -a "4NDR0666OS" "Clipboard Injected" "Target '$clean_cmd' lacks direct launch mapping."
			;;
		esac
	fi
fi

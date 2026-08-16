#!/usr/bin/env bash

# GDK BACKEND. Force wayland for Hyprland compatibility
BACKEND=wayland

# Process Termination: Clears the operational grid
if pidof rofi >/dev/null; then
	pkill rofi
fi

if pidof yad >/dev/null; then
	pkill yad
fi

# ==============================================================================
# DATA PAYLOAD: Array implementation guarantees syntax integrity and prevents
# line-continuation (\) breaking during copy/paste operations.
# ==============================================================================
declare -a KEYBINDS=(
	"<span weight='bold'>                        ===⦑     💀Ψ•-⦑  GENERAL  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" H" "Help / Cheat Sheet" "(KeyHints.sh)"
	" SHIFT H" "Brave Keybinds" "(Fkeyhints.sh)"
	" D" "Application Launcher" "(Rofi)"
	" B" "Open Default Browser" "(xdg-open)"
	" S" "Web Search" "(RofiSearch.sh)"
	" F" "File Manager" "(\$files)"
	" F1" "Clipboard Manager" "(ClipManager.sh)"
	" P" "Colorpicker" "(colorpicker)"
	" SHIFT K" "Search Keybinds" "(KeyBinds.sh)"
	" SHIFT E" "Quick Settings Menu" "(Kool_Quick_Settings.sh)"
	" SHIFT N" "Notifications Panel" "(makoctl)"
	" SHIFT N" "Night Light Toggle" "(Hyprsunset.sh)"
	" A" "Desktop Overview" "(OverviewToggle.sh)"
	" T" "Global Theme Switcher" "(ThemeChanger.sh)"
	" CTRL R" "Rofi Theme Selector" "(RofiThemeSelector.sh)"
	" CTRL SHIFT R" "Rofi Theme Selector (Mod)" "(RofiThemeSelector-modified.sh)"
	" N" "Network Manager" "(RofiNetwork.sh)"
	" ALT C" "Calculator" "(RofiCalc.sh)"
	" SHIFT M" "Online Music" "(RofiBeats.sh)"
	" W" "Select Wallpaper" "(WallpaperSelect.sh)"
	" SHIFT W" "Wallpaper Effects" "(WallpaperEffects.sh)"
	"CTRL ALT W" "Random Wallpaper" "(WallpaperRandom.sh)"
	" SHIFT A" "Animations Menu" "(Animations.sh)"
	" ALT E" "Emoji Menu" "(RofiEmoji.sh)"
	"ALT_L SHIFT_L" "Keyboard Layout Global" "(KeyboardLayout.sh)"
	"SHIFT_L ALT_L" "Keyboard Layout Window" "(Tak0-Per-Window-Switch.sh)"
	"CTRL ALT L" "Lock Screen" "(LockScreen.sh)"
	" X" "Powermenu" "(Wlogout.sh)"
	"CTRL ALT Del" "Exit Hyprland" "(hyprctl exit)"
	"" "" ""
	"<span weight='bold'>                         ===⦑     💀Ψ•-⦑  WAYBAR  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" CTRL ALT B" "Waybar Toggle" "(On/Off)"
	" CTRL B" "Waybar Styles" "(WaybarStyles.sh)"
	" ALT B" "Waybar Layouts" "(WaybarLayout.sh)"
	" ALT R" "Waybar Refresh" "(Refresh.sh)"
	"" "" ""
	"<span weight='bold'>                      ===⦑     💀Ψ•-⦑  TERMINALS  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" ENTER" "Open Terminal" "(\$term)"
	" SHIFT ENTER" "DropDown Terminal" "(Dropterminal.sh)"
	" ALT ENTER" "St Terminal" "(St)"
	" CTRL ENTER" "Alacritty" "(Alacritty)"
	"" "" ""
	"<span weight='bold'>                    ===⦑     💀Ψ•-⦑  SCREENSHOTS  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" SHIFT S" "Screenshot Menu" "(RofiScreenshot.sh)"
	"" "" ""
	"<span weight='bold'>                        ===⦑     💀Ψ•-⦑  WINDOWS  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" CTRL S" "Window Switcher" "(Rofi window)"
	" Q" "Close Active Window" "(killactive)"
	" SHIFT Q" "Terminate Process" "(KillActiveProcess.sh)"
	" SHIFT F" "Fullscreen" "(fullscreen)"
	" CTRL F" "Maximize Window" "(fake fullscreen)"
	" SPACE" "Float Current Window" "(togglefloating)"
	" ALT SPACE" "Float All Windows" "(workspaceopt allfloat)"
	" ALT O" "Toggle Blur" "(ChangeBlur.sh)"
	" CTRL O" "Toggle Active Opacity" "(setprop active opaque toggle)"
	"ALT TAB" "Cycle Next Window" "(cyclenext)"
	"" "" ""
	"<span weight='bold'>                        ===⦑     💀Ψ•-⦑  LAYOUTS  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" ALT L" "Toggle Master/Dwindle" "(ChangeLayout.sh)"
	" SHIFT I" "Remove Master" "(layoutmsg removemaster)"
	" I" "Add Master" "(layoutmsg addmaster)"
	" I" "Toggle Pseudo" "(pseudo)"
	" CTRL ENTER" "Swap with Master" "(layoutmsg swapwithmaster)"
	" M" "Set Split Ratio 0.3" "(splitratio 0.3)"
	"" "" ""
	"<span weight='bold'>                ===⦑     💀Ψ•-⦑  CUSTOM KEYBINDS  ⦒-•Ψ💀      ⦒===</span>" "" ""
	" F2" "File Manager" "(yazi)"
	" F3" "Text Editor" "(micro)"
	" SHIFT F3" "Text Editor" "(nvim)"
	" F5" "Media Player" "(play-with-mpv.py)"
	" F6" "Media Editor" "(vidcut)"
	" SHIFT F6" "Media Editor" "(losslesscut)"
	" F7" "Downloader" "(jdownloader)"
	" SHIFT F7" "Downloader" "(dmenuhandler)"
	" F8" "Service Manager" "(4ndr0service)"
	" SHIFT F8" "OOM Killer" "(trigger_oom.sh)"
	" F9" "Torrent Manager" "(torwrap)"
	" SHIFT F9" "Searchmaster" "(dorkmaster.py)"
	" F10" "Media Player" "(mpv)"
	" SHIFT F10" "Media Manager" "(wofi_media.sh)"
	" F12" "Screenrecorder" "(dmenurecord)"
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
		"Rofi window")
			rofi -show window &
			;;
		"makoctl")
			makoctl mode -t dnd &
			;;
		"Hyprsunset.sh")
			~/.config/hypr/scripts/Hyprsunset.sh toggle &
			;;
		"Quickshell")
			quickshell &
			;;
		"Wallpaper Menu")
			waypaper &
			;;
		"\$term")
			kitty &
			;;
		"St")
			/usr/local/bin/st &
			;;
		"Alacritty")
			~/.config/hypr/UserScripts/alacritty4ndr0666 &
			;;
		"xdg-open")
			xdg-open "https://" &
			;;
		"\$files")
			thunar &
			;;
		"Fkeyhints.sh")
			~/.config/hypr/UserScripts/Fkeyhints.sh &
			;;
		"colorpicker")
			~/.config/hypr/UserScripts/colorpicker &
			;;
		"yazi")
			kitty -e yazi --cwd-file $HOME/.cache/yazi/cwd_file &
			;;
		"micro")
			kitty -e micro &
			;;
		"nvim")
			kitty -e nvim &
			;;
		"play-with-mpv.py")
			python3 /usr/local/bin/play-with-mpv.py &
			;;
		"vidcut")
			/sbin/vidcut &
			;;
		"losslesscut")
			losslesscut &
			;;
		"jdownloader")
			jdownloader &
			;;
		"dmenuhandler")
			bash $HOME/.local/bin/dmenuhandler &
			;;
		"4ndr0service")
			bash 4ndr0service &
			;;
		"trigger_oom.sh")
			bash /usr/local/bin/trigger_oom.sh &
			;;
		"torwrap")
			kitty -e $HOME/.local/bin/torwrap /dev/null 2>&1 &
			;;
		"dorkmaster.py")
			st -e python3 /home/git/clone/4ndr0666/scr/media/dorkmaster/dorkmaster.py &
			;;
		"mpv")
			nohup mpv --profile=playdir &
			;;
		"wofi_media.sh")
			bash /home/andro/.local/bin/wofi_media.sh >/dev/null 2>&1 &
			;;
		"dmenurecord")
			bash $HOME/.local/bin/dmenurecord &
			;;
		"wlogout" | "Wlogout.sh")
			wlogout -b 5 -c 0 -r 0 -m 400 &
			;;
		"Hyprlock" | "LockScreen.sh")
			hyprlock &
			;;
			
		# ==============================================================================
		# Window Manager Dispatchers 
		# (Requires 'sleep' to allow the full-screen yad UI to unmap and return focus 
		# to the underlying target window before execution)
		# ==============================================================================
		"killactive")
			sleep 0.1 && hyprctl dispatch killactive &
			;;
		"fullscreen")
			sleep 0.1 && hyprctl dispatch fullscreen &
			;;
		"fake fullscreen")
			sleep 0.1 && hyprctl dispatch fullscreen 1 &
			;;
		"togglefloating")
			sleep 0.1 && hyprctl dispatch togglefloating &
			;;
		"workspaceopt allfloat")
			sleep 0.1 && hyprctl dispatch workspaceopt allfloat &
			;;
		"setprop active opaque toggle")
			sleep 0.1 && hyprctl dispatch setprop active opaque toggle &
			;;
		"cyclenext")
			sleep 0.1 && hyprctl dispatch cyclenext &
			;;
		"layoutmsg removemaster")
			sleep 0.1 && hyprctl dispatch layoutmsg removemaster &
			;;
		"layoutmsg addmaster")
			sleep 0.1 && hyprctl dispatch layoutmsg addmaster &
			;;
		"pseudo")
			sleep 0.1 && hyprctl dispatch pseudo &
			;;
		"layoutmsg swapwithmaster")
			sleep 0.1 && hyprctl dispatch layoutmsg swapwithmaster &
			;;
		"splitratio 0.3")
			sleep 0.1 && hyprctl dispatch splitratio 0.3 &
			;;
		"hyprctl exit")
			hyprctl dispatch exit 0
			;;
			
		*.sh | *.py)
			kitty -e "$clean_cmd" &
			;;
		"")
			echo -n "$selected_key" | wl-copy
			notify-send -u low -a "4NDR0666OS" "Clipboard Injected" "Keybind $selected_key copied (No direct exec mapped)."
			;;
		*)
			echo -n "$selected_key" | wl-copy
			notify-send -u low -a "4NDR0666OS" "Clipboard Injected" "Target '$clean_cmd' lacks direct launch mapping."
			;;
		esac
	fi
fi

#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Rofi menu for KooL Hyprland Quick Settings (SUPER SHIFT E)

config_file="$HOME/.config/hypr/UserConfigs/01-UserDefaults.lua"

if [[ -f "$config_file" ]]; then
    term=$(grep -E '^\s*local\s+term\s*=' "$config_file" | sed -E 's/.*=\s*"([^"]*)".*/\1/')
    edit=$(grep -E '^\s*hl\.env\("EDITOR",' "$config_file" | sed -E 's/.*,\s*"([^"]*)".*/\1/')
fi

[[ -z "$term" ]] && term="kitty"
[[ -z "$edit" ]] && edit="${EDITOR:-micro}"

configs="$HOME/.config/hypr/configs"
UserConfigs="$HOME/.config/hypr/UserConfigs"
rofi_theme="$HOME/.config/rofi/config-edit.rasi"
msg=' Make selection: '
iDIR="$HOME/.config/swaync/images"
scriptsDir="$HOME/.config/hypr/scripts"
UserScripts="$HOME/.config/hypr/UserScripts"

show_info() {
    if [[ -f "$iDIR/info.png" ]]; then
        notify-send -i "$iDIR/info.png" "Info" "$1"
    elif [[ -f "$iDIR/note.png" ]]; then
        notify-send -i "$iDIR/note.png" "Info" "$1"
    else
        notify-send "Info" "$1"
    fi
}

toggle_rainbow_borders() {
    local toggle_script="$scriptsDir/RainbowBordersToggle.sh"
    [[ -f "$toggle_script" ]] || {
        show_info "Rainbow Borders toggle helper is missing."
        return 127
    }
    bash "$toggle_script" toggle
}

rainbow_borders_menu() {
    local rainbow_script="$UserScripts/RainbowBorders.sh"
    local current="disabled"
    if [[ -f "$rainbow_script" ]]; then
        current=$(grep -E '^EFFECT_TYPE=' "$rainbow_script" 2>/dev/null | sed -E 's/^EFFECT_TYPE="?([^"]*)"?/\1/')
        [[ -z "$current" ]] && current="unknown"
    fi

    local current_display="$current"
    case "$current" in
        wallust_random) current_display="Wallust Color" ;;
        rainbow) current_display="Original Rainbow" ;;
        gradient_flow) current_display="Gradient Flow" ;;
        disabled) current_display="Disabled" ;;
    esac

    local options="Toggle Rainbow Borders\nDisable Rainbow Borders\nWallust Color\nOriginal Rainbow\nGradient Flow"
    local choice
    choice=$(printf "%b" "$options" | rofi -i -dmenu -config "$rofi_theme" -mesg "Rainbow Borders: current = $current_display")

    [[ -z "$choice" ]] && return

    case "$choice" in
        "Toggle Rainbow Borders")
            toggle_rainbow_borders
            return $?
            ;;
        "Disable Rainbow Borders")
            bash "$scriptsDir/RainbowBordersToggle.sh" --disable
            return $?
            ;;
        "Wallust Color"|"Original Rainbow"|"Gradient Flow")
            local mode=""
            case "$choice" in
                "Wallust Color") mode="wallust_random" ;;
                "Original Rainbow") mode="rainbow" ;;
                "Gradient Flow") mode="gradient_flow" ;;
            esac
            bash "$scriptsDir/RainbowBordersToggle.sh" --mode "$mode"
            return $?
            ;;
        *)
            return ;;
    esac

}

menu() {
    cat <<EOF
--- USER CUSTOMIZATIONS ---
Edit User Defaults
Edit User Keybinds
Edit User ENV variables
Edit User Startup Apps (overlay)
Edit User Window Rules (overlay)
Edit User Settings
Edit User Decorations
Edit User Animations
Edit User Laptop Settings
Edit User Workspace Rules
--- SYSTEM DEFAULTS  ---
Edit System Default Keybinds
Edit System Default Startup Apps
Edit System Default Window Rules
Edit System Default Settings
--- UTILITIES ---
Set SDDM Wallpaper
Choose Kitty Terminal Theme
Configure Monitors (nwg-displays)
Configure Workspace Rules (nwg-displays)
GTK Settings (nwg-look)
QT Apps Settings (qt6ct)
QT Apps Settings (qt5ct)
Choose Hyprland Animations
Choose Monitor Profiles
Choose Rofi Themes
Search for Keybinds
Toggle Game Mode
Switch Dark-Light Theme
Rainbow Borders Mode
EOF
}

main() {
    choice=$(menu | rofi -i -dmenu -config $rofi_theme -mesg "$msg")
    
    case "$choice" in
    	"Edit User Defaults") file="$UserConfigs/01-UserDefaults.lua" ;;
        "Edit User ENV variables") file="$UserConfigs/ENVariables.lua" ;;
        "Edit User Keybinds") file="$UserConfigs/UserKeybinds.lua" ;;
        "Edit User Startup Apps (overlay)") file="$UserConfigs/Startup_Apps.lua" ;;
        "Edit User Window Rules (overlay)") file="$UserConfigs/WindowRules.lua" ;;
        "Edit User Settings") file="$UserConfigs/UserSettings.lua" ;;
        "Edit User Decorations") file="$UserConfigs/UserDecorations.lua" ;;
        "Edit User Animations") file="$UserConfigs/UserAnimations.lua" ;;
        "Edit User Laptop Settings") file="$UserConfigs/Laptops.lua" ;;
        "Edit User Workspace Rules") file="$UserConfigs/WorkSpaceRules.lua" ;;
        "Edit System Default Keybinds") file="$configs/Keybinds.lua" ;;
        "Edit System Default Startup Apps") file="$configs/Startup_Apps.lua" ;;
        "Edit System Default Window Rules") file="$configs/WindowRules.lua" ;;
        "Edit System Default Settings") file="$configs/SystemSettings.lua" ;;
        "Set SDDM Wallpaper") $scriptsDir/sddm_wallpaper.sh --normal ;;
        "Choose Kitty Terminal Theme") $scriptsDir/Kitty_themes.sh ;;
        "Configure Monitors (nwg-displays)") 
            if ! command -v nwg-displays &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install nwg-displays first"
                exit 1
            fi
            nwg-displays ;;
        "Configure Workspace Rules (nwg-displays)") 
            if ! command -v nwg-displays &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install nwg-displays first"
                exit 1
            fi
            nwg-displays ;;
		"GTK Settings (nwg-look)") 
            if ! command -v nwg-look &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install nwg-look first"
                exit 1
            fi
            nwg-look ;;
		"QT Apps Settings (qt6ct)") 
            if ! command -v qt6ct &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install qt6ct first"
                exit 1
            fi
            qt6ct ;;
		"QT Apps Settings (qt5ct)") 
            if ! command -v qt5ct &>/dev/null; then
                notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Install qt5ct first"
                exit 1
            fi
            qt5ct ;;
        "Choose Hyprland Animations") $scriptsDir/Animations.sh ;;
        "Choose Monitor Profiles") $scriptsDir/MonitorProfiles.sh ;;
        "Choose Rofi Themes") $scriptsDir/RofiThemeSelector.sh ;;
        "Search for Keybinds") $scriptsDir/KeyBinds.sh ;;
        "Toggle Game Mode") $scriptsDir/GameMode.sh ;;
        "Switch Dark-Light Theme") $scriptsDir/DarkLight.sh ;;
        "Rainbow Borders Mode") rainbow_borders_menu || return $? ;;
        *) return ;;
    esac

    if [ -n "$file" ]; then
        $term -e $edit "$file"
    fi
}

if [[ "${1:-}" == "--toggle-rainbow-borders" ]]; then
    toggle_rainbow_borders
    exit $?
fi

if pidof rofi > /dev/null; then
  pkill rofi
fi

main

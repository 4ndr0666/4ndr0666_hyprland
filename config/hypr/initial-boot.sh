#!/usr/bin/env bash
# A bash script designed to run only once after dotfiles installation.
#
# The script exits immediately after creating ~/.config/hypr/.initial_startup_done.
# It is intentionally retained for the one-time initialization flow.
# User-owned persistent configuration belongs in ~/.config/hypr/UserConfigs/.

set -Eeuo pipefail

# Variables
scriptsDir="$HOME/.config/hypr/scripts"
wallpaper="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
waybar_style="$HOME/.config/waybar/style/[Colorful] stolen-style.css"
kvantum_theme="Colorful-Dark-Kvantum#"
color_scheme="prefer-dark"
gtk_theme="Colorful-Dark"
icon_theme="Colorful-Dark-Icons"
cursor_theme="Bibata-Modern-Ice"

awww_cmd=(awww img)
effect=(--transition-bezier .43,1.19,1,.4 --transition-fps 30 --transition-type grow --transition-pos 0.925,0.977 --transition-duration 2)

# Check if a marker file exists.
if [[ ! -f "$HOME/.config/hypr/.initial_startup_done" ]]; then
    sleep 1

    # Initialize the wallpaper daemon and generate the palette exactly once.
    if [[ -f "$wallpaper" ]]; then
        # The canonical initializer owns daemon startup in a separate hook.
        # Wait for actual readiness; one fixed sleep races its portal startup.
        for _ in {1..100}; do
            awww query >/dev/null 2>&1 && break
            sleep 0.1
        done
        awww query >/dev/null 2>&1 || {
            printf '%s\n' '[ERROR] awww-daemon is not ready; refusing to start a second owner.' >&2
            exit 1
        }
        "${awww_cmd[@]}" "$wallpaper" "${effect[@]}"
        "$scriptsDir/WallustAwww.sh" "$wallpaper"
    fi

    gsettings set org.gnome.desktop.interface color-scheme "$color_scheme" >/dev/null 2>&1 &
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" >/dev/null 2>&1 &
    gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" >/dev/null 2>&1 &
    gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme" >/dev/null 2>&1 &
    gsettings set org.gnome.desktop.interface cursor-size 24 >/dev/null 2>&1 &

    if grep -qi nixos /etc/os-release; then
        gsettings set org.gnome.desktop.interface color-scheme "'$color_scheme'" >/dev/null 2>&1 &
        dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'" >/dev/null 2>&1 &
        dconf write /org/gnome/desktop/interface/icon-theme "'$icon_theme'" >/dev/null 2>&1 &
        dconf write /org/gnome/desktop/interface/cursor-theme "'$cursor_theme'" >/dev/null 2>&1 &
        dconf write /org/gnome/desktop/interface/cursor-size "24" >/dev/null 2>&1 &
    fi

    # The deployed Kvantum config already selects this theme. Avoid opening
    # the GUI for a missing theme; only select an installed theme.
    kvantum_dir="${XDG_CONFIG_HOME:-$HOME/.config}/Kvantum"
    if [[ -f "$kvantum_dir/$kvantum_theme/$kvantum_theme.kvconfig" ]] &&
       ! grep -Fxq "theme=$kvantum_theme" "$kvantum_dir/kvantum.kvconfig" 2>/dev/null &&
       command -v kvantummanager >/dev/null 2>&1; then
        kvantummanager --set "$kvantum_theme" >/dev/null 2>&1 &
    fi

    if [[ -L "$HOME/.config/waybar/config" ]]; then
        "$scriptsDir/Refresh.sh" >/dev/null 2>&1 &
    fi

    # Create a marker file to indicate that the script has been executed.
    touch "$HOME/.config/hypr/.initial_startup_done"

    exit 0
fi

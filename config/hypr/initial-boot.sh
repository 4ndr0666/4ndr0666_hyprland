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
kvantum_theme="Colorful-Dark"
color_scheme="prefer-dark"
gtk_theme="Colorful-Dark"
icon_theme="Colorful-Dark"
cursor_theme="Bibata-Modern-Ice"

awww="awww img"
effect=(--transition-bezier .43,1.19,1,.4 --transition-fps 30 --transition-type grow --transition-pos 0.925,0.977 --transition-duration 2)

# Check if a marker file exists.
if [[ ! -f "$HOME/.config/hypr/.initial_startup_done" ]]; then
    sleep 1

    # Initialize the wallpaper daemon and generate the palette exactly once.
    if [[ -f "$wallpaper" ]]; then
        if ! awww query >/dev/null 2>&1; then
            awww-daemon --format xrgb
        fi
        "$scriptsDir/WallustAwww.sh" "$wallpaper"
        "$awww" "$wallpaper" "${effect[@]}"
    fi

    gsettings set org.gnome.desktop.interface color-scheme "$color_scheme" >/dev/null 2>&1 &
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" >/dev/null 2>&1 &
    gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" >/dev/null 2>&1 &
    gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme" >/dev/null 2>&1 &
    gsettings set org.gnome.desktop.interface cursor-size 0 >/dev/null 2>&1 &

    if grep -qi nixos /etc/os-release; then
        gsettings set org.gnome.desktop.interface color-scheme "'$color_scheme'" >/dev/null 2>&1 &
        dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'" >/dev/null 2>&1 &
        dconf write /org/gnome/desktop/interface/icon-theme "'$icon_theme'" >/dev/null 2>&1 &
        dconf write /org/gnome/desktop/interface/cursor-theme "'$cursor_theme'" >/dev/null 2>&1 &
        dconf write /org/gnome/desktop/interface/cursor-size "24" >/dev/null 2>&1 &
    fi

    # initiate kvantum theme
    kvantummanager --set "$kvantum_theme" >/dev/null 2>&1 &

    if [[ -L "$HOME/.config/waybar/config" ]]; then
        "$scriptsDir/Refresh.sh" >/dev/null 2>&1 &
    fi

    # Create a marker file to indicate that the script has been executed.
    touch "$HOME/.config/hypr/.initial_startup_done"

    exit 0
fi

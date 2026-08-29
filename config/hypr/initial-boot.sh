#!/usr/bin/env bash
# A bash script designed to run only once dotfiles installed

# THIS SCRIPT CAN BE DELETED ONCE SUCCESSFULLY BOOTED!! And also, edit ~/.config/hypr/configs/Settings.conf
# NOT necessary to do since this script is only designed to run only once as long as the marker exists
# marker file is located at ~/.config/hypr/.initial_startup_done
# However, I do highly suggest not to touch it since again, as long as the marker exist, script wont run

# Variables
scriptsDir=$HOME/.config/hypr/scripts
wallpaper=$HOME/.config/hypr/wallpaper_effects/.wallpaper_current
waybar_style="$HOME/.config/waybar/style/[Colorful] stolen-style.css"
kvantum_theme="Colorful-Dark"
color_scheme="prefer-dark"
gtk_theme="Colorful-Dark"
icon_theme="Colorful-Dark"
cursor_theme="Bibata-Modern-Ice"

awww="awww img"
effect="--transition-bezier .43,1.19,1,.4 --transition-fps 30 --transition-type grow --transition-pos 0.925,0.977 --transition-duration 2"

if [ ! -f "$HOME/.config/hypr/.initial_startup_done" ]; then
    sleep 1
    if [ -f "$wallpaper" ]; then
        wallust run -s "$wallpaper" > /dev/null
        awww query || awww-daemon && $awww "$wallpaper" $effect
        "$scriptsDir/WallustAwww.sh" > /dev/null 2>&1 &
    fi

    gsettings set org.gnome.desktop.interface color-scheme "$color_scheme" > /dev/null 2>&1 &
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" > /dev/null 2>&1 &
    gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" > /dev/null 2>&1 &
    gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme" > /dev/null 2>&1 &
    gsettings set org.gnome.desktop.interface cursor-size 0 > /dev/null 2>&1 &

    if [ -n "$(grep -i nixos < /etc/os-release)" ]; then
        gsettings set org.gnome.desktop.interface color-scheme "'$color_scheme'" > /dev/null 2>&1 &
        dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'" > /dev/null 2>&1 &
        dconf write /org/gnome/desktop/interface/icon-theme "'$icon_theme'" > /dev/null 2>&1 &
        dconf write /org/gnome/desktop/interface/cursor-theme "'$cursor_theme'" > /dev/null 2>&1 &
        dconf write /org/gnome/desktop/interface/cursor-size "24" > /dev/null 2>&1 &
    fi

    kvantummanager --set "$kvantum_theme" > /dev/null 2>&1 &

    if [ -L "$HOME/.config/waybar/config" ]; then
        "$scriptsDir/Refresh.sh" > /dev/null 2>&1 &
    fi

    touch "$HOME/.config/hypr/.initial_startup_done"
    exit
fi

#!/usr/bin/env bash
## /* ----  https://github.com/4ndr0666  ---- */  ##
# For Dark and Light switching
# Note: Scripts are looking for keywords Light or Dark except for wallpapers as they are in separate directories

set -Eeuo pipefail

# Paths
PICTURES_DIR="$HOME"
wallpaper_base_path="$HOME/Wallpapers/Dynamic-Wallpapers"
dark_wallpapers="$wallpaper_base_path/Dark"
light_wallpapers="$wallpaper_base_path/Light"
hypr_config_path="$HOME/.config/hypr"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
notif="$HOME/.config/mako/images/bell.png"

kitty_conf="$HOME/.config/kitty/kitty.conf"

wallust_config="$HOME/.config/wallust/wallust.toml"
pallete_dark="dark16"
pallete_light="light16"
qt5ct_dark="$HOME/.config/qt5ct/colors/Catppuccin-Mocha.conf"
qt5ct_light="$HOME/.config/qt5ct/colors/Catppuccin-Latte.conf"
qt6ct_dark="$HOME/.config/qt6ct/colors/Catppuccin-Mocha.conf"
qt6ct_light="$HOME/.config/qt6ct/colors/Catppuccin-Latte.conf"

# Stop theme consumers before applying the new mode.
for pid in waybar rofi mako swaybg; do
    killall -SIGUSR1 "$pid" >/dev/null 2>&1 || true
done

# Initialize awww if needed.
awww query >/dev/null 2>&1 || awww-daemon --format xrgb

# Set awww options as an array so paths and arguments remain word-safe.
awww_cmd=(awww img)
effect=(--transition-bezier .43,1.19,1,.4 --transition-fps 60 --transition-type grow --transition-pos 0.925,0.977 --transition-duration 2)

# Determine current theme mode.
if [[ "$(cat "$HOME/.cache/.theme_mode")" == "Light" ]]; then
    next_mode="Dark"
    wallpaper_path="$dark_wallpapers"
else
    next_mode="Light"
    wallpaper_path="$light_wallpapers"
fi

# Select Qt color scheme templates for the upcoming mode.
if [[ "$next_mode" == "Dark" ]]; then
    qt5ct_color_scheme="$qt5ct_dark"
    qt6ct_color_scheme="$qt6ct_dark"
else
    qt5ct_color_scheme="$qt5ct_light"
    qt6ct_color_scheme="$qt6ct_light"
fi

update_theme_mode() {
    printf '%s\n' "$next_mode" > "$HOME/.cache/.theme_mode"
}

notify_user() {
    notify-send -u low -i "$notif" " Switching to" " $1 mode"
}

# Select the palette for the next Wallust generation.
if [[ "$next_mode" == "Dark" ]]; then
    sed -i 's/^palette = .*/palette = "dark16"/' "$wallust_config"
else
    sed -i 's/^palette = .*/palette = "light16"/' "$wallust_config"
fi

set_waybar_style() {
    local theme="$1"
    local waybar_styles="$HOME/.config/waybar/style"
    local waybar_style_link="$HOME/.config/waybar/style.css"
    local style_prefix="\\[${theme}\\].*\\.css$"
    local style_file

    style_file=$(find -L "$waybar_styles" -maxdepth 1 -type f -regex ".*$style_prefix" | shuf -n 1)

    if [[ -n "$style_file" ]]; then
        ln -sf "$style_file" "$waybar_style_link"
    else
        printf '%s\n' "[ERROR] Style file not found for $theme theme." >&2
        return 1
    fi
}

set_waybar_style "$next_mode"
notify_user "$next_mode"

# Update Kitty colors.
if [[ "$next_mode" == "Dark" ]]; then
    sed -i '/^foreground /s/^foreground .*/foreground #dddddd/' "$kitty_conf"
    sed -i '/^background /s/^background .*/background #000000/' "$kitty_conf"
    sed -i '/^cursor /s/^cursor .*/cursor #dddddd/' "$kitty_conf"
else
    sed -i '/^foreground /s/^foreground .*/foreground #000000/' "$kitty_conf"
    sed -i '/^background /s/^background .*/background #dddddd/' "$kitty_conf"
    sed -i '/^cursor /s/^cursor .*/cursor #000000/' "$kitty_conf"
fi

while IFS= read -r -d '' pid_kitty; do
    kill -SIGUSR1 "$pid_kitty"
done < <(pidof -z kitty 2>/dev/null || true)

# Select the next wallpaper without word-splitting the path.
if [[ "$next_mode" == "Dark" ]]; then
    next_wallpaper="$(find -L "$dark_wallpapers" -type f \( -iname '*.jpg' -o -iname '*.png' \) -print0 | shuf -n1 -z | xargs -0 -r printf '%s')"
else
    next_wallpaper="$(find -L "$light_wallpapers" -type f \( -iname '*.jpg' -o -iname '*.png' \) -print0 | shuf -n1 -z | xargs -0 -r printf '%s')"
fi

if [[ -z "$next_wallpaper" ]]; then
    printf '%s\n' '[ERROR] No wallpaper was found for the selected theme.' >&2
    exit 1
fi

# Set dynamic wallpaper and regenerate/validate Wallust consumers from that exact image.
"${awww_cmd[@]}" "$next_wallpaper" "${effect[@]}"
"${SCRIPTSDIR}/WallustAwww.sh" "$next_wallpaper"

# Set Kvantum Manager theme & QT5/QT6 settings.
if [[ "$next_mode" == "Dark" ]]; then
    kvantum_theme="catppuccin-mocha-blue"
else
    kvantum_theme="catppuccin-latte-blue"
fi

sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt5ct_color_scheme|" "$HOME/.config/qt5ct/qt5ct.conf"
sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt6ct_color_scheme|" "$HOME/.config/qt6ct/qt6ct.conf"
kvantummanager --set "$kvantum_theme"

# GTK themes and icons switching.
set_custom_gtk_theme() {
    local mode="$1"
    local gtk_themes_directory="$HOME/.themes"
    local icon_directory="$HOME/.icons"
    local color_setting='org.gnome.desktop.interface color-scheme'
    local theme_setting='org.gnome.desktop.interface gtk-theme'
    local icon_setting='org.gnome.desktop.interface icon-theme'
    local search_keywords
    local selected_theme
    local selected_icon
    local -a themes=()
    local -a icons=()

    case "$mode" in
        Light)
            search_keywords='*Light*'
            gsettings set "$color_setting" 'prefer-light'
            ;;
        Dark)
            search_keywords='*Dark*'
            gsettings set "$color_setting" 'prefer-dark'
            ;;
        *)
            printf '%s\n' '[ERROR] Invalid GTK theme mode.' >&2
            return 1
            ;;
    esac

    while IFS= read -r -d '' theme_search; do
        themes+=("$(basename "$theme_search")")
    done < <(find "$gtk_themes_directory" -maxdepth 1 -type d -iname "$search_keywords" -print0)

    while IFS= read -r -d '' icon_search; do
        icons+=("$(basename "$icon_search")")
    done < <(find "$icon_directory" -maxdepth 1 -type d -iname "$search_keywords" -print0)

    if ((${#themes[@]} > 0)); then
        selected_theme="${themes[RANDOM % ${#themes[@]}]}"
        printf '%s\n' "Selected GTK theme for $mode mode: $selected_theme"
        gsettings set "$theme_setting" "$selected_theme"

        if command -v flatpak >/dev/null 2>&1; then
            flatpak --user override --filesystem="$HOME/.themes"
            sleep 0.5
            flatpak --user override --env=GTK_THEME="$selected_theme"
        fi
    else
        printf '%s\n' "No $mode GTK theme found"
    fi

    if ((${#icons[@]} > 0)); then
        selected_icon="${icons[RANDOM % ${#icons[@]}]}"
        printf '%s\n' "Selected icon theme for $mode mode: $selected_icon"
        gsettings set "$icon_setting" "$selected_icon"

        sed -i "s|^icon_theme=.*$|icon_theme=$selected_icon|" "$HOME/.config/qt5ct/qt5ct.conf"
        sed -i "s|^icon_theme=.*$|icon_theme=$selected_icon|" "$HOME/.config/qt6ct/qt6ct.conf"

        if command -v flatpak >/dev/null 2>&1; then
            flatpak --user override --filesystem="$HOME/.icons"
            sleep 0.5
            flatpak --user override --env=ICON_THEME="$selected_icon"
        fi
    else
        printf '%s\n' "No $mode icon theme found"
    fi
}

set_custom_gtk_theme "$next_mode"
update_theme_mode

sleep 2
for pid in waybar rofi mako swaybg; do
    killall "$pid" >/dev/null 2>&1 || true
done

sleep 1
"${SCRIPTSDIR}/Refresh.sh"

sleep 0.5
notify-send -u low -i "$notif" " Themes switched to:" " $next_mode Mode"

exit 0

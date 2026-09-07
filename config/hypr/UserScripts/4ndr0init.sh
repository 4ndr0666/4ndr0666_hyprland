#!/usr/bin/env bash
# 4ndr0666
# === [ 4NDR0INIT.sh ] ===
# Desc: Synchronous initialization for D-Bus, Environment, and Portals.
# -----------------------------------------------------------------
set -euo pipefail

# Establish a usable D-Bus session before publishing the Wayland environment.
if ! dbus-send --session --dest=org.freedesktop.DBus \
    --type=method_call --print-reply \
    /org/freedesktop/DBus org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
    if [[ -S "/run/user/${UID}/bus" ]]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${UID}/bus"
        export DBUS_SESSION_BUS_PID
    else
        eval "$(dbus-launch --sh-syntax --exit-with-session)"
    fi
fi

: "${DBUS_SESSION_BUS_ADDRESS:?D-Bus session bus address is unavailable}"
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

kill_quietly() {
    killall -q "$1" 2>/dev/null || true
}

start_portal_binary() {
    local description="$1"
    shift
    for candidate in "$@"; do
        if [[ -x "$candidate" ]]; then
            "$candidate" &
            return 0
        fi
    done
    printf 'ERROR: no %s binary found (checked: %s)\n' "$description" "$*" >&2
    return 1
}

sleep 1
kill_quietly waybar
kill_quietly mako
kill_quietly xdg-desktop-portal-hyprland
kill_quietly xdg-desktop-portal-wlr
kill_quietly xdg-desktop-portal-gnome
kill_quietly xdg-desktop-portal
sleep 1

# Start the Hyprland portal implementation first, then the generic portal.
start_portal_binary "xdg-desktop-portal-hyprland" \
    /usr/lib/xdg-desktop-portal-hyprland \
    /usr/libexec/xdg-desktop-portal-hyprland

sleep 2

start_portal_binary "xdg-desktop-portal" \
    /usr/lib/xdg-desktop-portal \
    /usr/libexec/xdg-desktop-portal

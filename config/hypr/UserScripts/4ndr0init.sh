#!/usr/bin/env bash
# 4ndr0666
# === [ 4NDR0INIT.sh ] ===
# Desc: Synchronous initialization for D-Bus, Environment, Portals, and graphical runtime daemons.
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

started_process_pids=()

cleanup_started_processes() {
    local pid
    local cleanup_failed=0
    for pid in "${started_process_pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            if ! kill "$pid" 2>/dev/null; then
                if kill -0 "$pid" 2>/dev/null; then
                    printf 'ERROR: failed to stop portal process %s during rollback\n' "$pid" >&2
                    cleanup_failed=1
                    continue
                fi
            fi
        fi

        if wait "$pid"; then
            :
        else
            local status=$?
            case "$status" in
                130|137|143) ;;
                *)
                    printf 'ERROR: portal process %s exited with status %s during rollback\n' "$pid" "$status" >&2
                    cleanup_failed=1
                    ;;
            esac
        fi
    done

    return "$cleanup_failed"
}

on_exit() {
    local status=$?
    if (( status != 0 )) && ((${#started_process_pids[@]} > 0)); then
        if ! cleanup_started_processes; then
            printf 'ERROR: graphical runtime startup rollback failed\n' >&2
            status=1
        fi
    fi
    exit "$status"
}
trap on_exit EXIT

start_process() {
    local description="$1"
    shift
    local candidate pid status
    for candidate in "$@"; do
        if [[ -x "$candidate" ]]; then
            "$candidate" &
            pid=$!
            sleep 0.2
            if kill -0 "$pid" 2>/dev/null; then
                started_process_pids+=("$pid")
                return 0
            fi

            if wait "$pid"; then
                printf 'ERROR: %s exited before becoming ready (pid %s)\n' "$description" "$pid" >&2
                return 1
            else
                status=$?
                printf 'ERROR: %s exited during startup with status %s (pid %s)\n' "$description" "$status" "$pid" >&2
                return "$status"
            fi
        fi
    done
    printf 'ERROR: no %s binary found (checked: %s)\n' "$description" "$*" >&2
    return 1
}

sleep 1
kill_quietly xdg-desktop-portal-hyprland
kill_quietly xdg-desktop-portal-wlr
kill_quietly xdg-desktop-portal-gnome
kill_quietly xdg-desktop-portal
sleep 1

# Start the Hyprland portal implementation first, then the generic portal.
start_process "xdg-desktop-portal-hyprland" \
    /usr/lib/xdg-desktop-portal-hyprland \
    /usr/libexec/xdg-desktop-portal-hyprland

sleep 2

start_process "xdg-desktop-portal" \
    /usr/lib/xdg-desktop-portal \
    /usr/libexec/xdg-desktop-portal

started_process_pids=()

start_process "awww-daemon" awww-daemon --format xrgb

for _ in {1..20}; do
    if awww query >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done
awww query >/dev/null 2>&1 || {
    printf 'ERROR: awww-daemon did not become queryable after startup\n' >&2
    exit 1
}

start_process "waybar" waybar

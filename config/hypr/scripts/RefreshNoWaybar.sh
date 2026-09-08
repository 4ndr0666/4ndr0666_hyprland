#!/usr/bin/env bash
# /* ----  https://github.com/4ndr0666  ---- */  ##

# Modified version of Refresh.sh that does not refresh Waybar.
# Used by automatic wallpaper change to refresh consumers that do not depend
# on Waybar's Wallust palette reload.

set -Eeuo pipefail

USER_SCRIPTS="$HOME/.config/hypr/UserScripts"

started_pids=()
restore_rofi=0

cleanup_started() {
    local cleanup_status=0
    local pid
    for pid in "${started_pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            if kill "$pid" 2>/dev/null; then
                :
            else
                local rc=$?
                ((rc == 1)) || cleanup_status=$rc
            fi
        fi
    done
    started_pids=()
    return "$cleanup_status"
}

start_component() {
    local label="$1"
    shift
    "$@" >/dev/null 2>&1 &
    local pid=$!
    started_pids+=("$pid")

    if kill -0 "$pid" 2>/dev/null; then
        return 0
    fi

    local rc=0
    wait "$pid" || rc=$?
    printf '%s\n' "RefreshNoWaybar lifecycle failure: $label exited during startup with status $rc" >&2
    return 1
}

rollback() {
    local rollback_status=0
    local cleanup_rc=0

    cleanup_started || cleanup_rc=$?
    if ((restore_rofi)); then
        if start_component 'rollback-rofi' rofi; then
            unset 'started_pids[-1]'
        else
            rollback_status=$?
        fi
    fi
    restore_rofi=0

    local rollback_cleanup_rc=0
    cleanup_started || rollback_cleanup_rc=$?
    if ((cleanup_rc != 0)); then
        printf '%s\n' "RefreshNoWaybar lifecycle cleanup failed with status $cleanup_rc" >&2
        rollback_status=$cleanup_rc
    fi
    if ((rollback_cleanup_rc != 0)); then
        printf '%s\n' "RefreshNoWaybar lifecycle rollback cleanup failed with status $rollback_cleanup_rc" >&2
        rollback_status=$rollback_cleanup_rc
    fi
    return "$rollback_status"
}

cleanup() {
    local rc=$?
    if ((rc != 0)); then
        local rollback_rc=0
        rollback || rollback_rc=$?
        if ((rollback_rc != 0)); then
            printf '%s\n' "RefreshNoWaybar lifecycle rollback failed with status $rollback_rc" >&2
            rc=$rollback_rc
        fi
    else
        started_pids=()
        restore_rofi=0
    fi
    return "$rc"
}
trap cleanup EXIT

if pgrep -x -- rofi >/dev/null 2>&1; then
    restore_rofi=1
else
    local_rc=$?
    ((local_rc == 1)) || exit "$local_rc"
fi

if pkill -- rofi >/dev/null 2>&1; then
    :
else
    rc=$?
    ((rc == 1)) || { printf '%s\n' "RefreshNoWaybar lifecycle failure: rofi teardown failed with status $rc" >&2; exit "$rc"; }
fi

swaync-client --reload-config

if [[ -x "${USER_SCRIPTS}/RainbowBorders.sh" ]]; then
    start_component RainbowBorders "${USER_SCRIPTS}/RainbowBorders.sh"
fi

started_pids=()
restore_rofi=0
exit 0

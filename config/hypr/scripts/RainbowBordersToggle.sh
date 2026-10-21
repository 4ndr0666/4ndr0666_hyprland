#!/usr/bin/env bash
set -Eeuo pipefail

# Toggle or disable the managed Rainbow Borders runtime script.
# The archival RainbowBorders.bak.sh template is deliberately never used.
HYPR_ROOT="${HOME}/.config/hypr"
ACTIVE="${HYPR_ROOT}/UserScripts/RainbowBorders.sh"
DISABLED="${ACTIVE}.bak"
REFRESH="${HYPR_ROOT}/scripts/Refresh.sh"

fail() {
    printf 'Rainbow Borders toggle: %s\n' "$*" >&2
    command -v notify-send >/dev/null 2>&1 && notify-send "Rainbow Borders" "$*" || true
    return 1
}

refresh_borders() {
    if [[ -x "$REFRESH" ]]; then
        "$REFRESH" >/dev/null 2>&1
    elif [[ -x "$ACTIVE" ]]; then
        "$ACTIVE" >/dev/null 2>&1
    else
        fail "No executable Refresh.sh or RainbowBorders.sh is available."
    fi
}

disable_borders() {
    command -v hyprctl >/dev/null 2>&1 || {
        fail "Cannot disable borders because hyprctl is unavailable."
        return 1
    }
    if [[ -e "$ACTIVE" && -e "$DISABLED" ]]; then
        fail "Both active and disabled scripts exist; state is inconsistent and no files were changed."
        return 1
    fi
    if [[ -e "$ACTIVE" ]]; then
        [[ -x "$ACTIVE" ]] || {
            fail "RainbowBorders.sh is not executable; no files were changed."
            return 1
        }
        mv -- "$ACTIVE" "$DISABLED" || {
            fail "Could not move the active script to its managed disabled path."
            return 1
        }
    elif [[ ! -f "$DISABLED" ]]; then
        fail "Neither the active script nor its managed disabled copy exists."
        return 1
    fi
    if hyprctl reload >/dev/null 2>&1; then
        return 0
    fi
    if [[ -f "$DISABLED" && ! -e "$ACTIVE" ]]; then
        mv -- "$DISABLED" "$ACTIVE" || {
            fail "Reload failed and rollback could not restore the active script."
            return 1
        }
    fi
    fail "Hyprland reload failed; the previous active state was restored."
    return 1
}

enable_borders() {
    if [[ -e "$ACTIVE" && -e "$DISABLED" ]]; then
        fail "Both active and disabled scripts exist; state is inconsistent and no files were changed."
        return 1
    fi
    if [[ ! -e "$ACTIVE" ]]; then
        [[ -f "$DISABLED" ]] || {
            fail "No managed disabled RainbowBorders.sh exists; the archival .bak.sh template is not a fallback."
            return 1
        }
        mv -- "$DISABLED" "$ACTIVE" || {
            fail "Could not restore the managed disabled script."
            return 1
        }
    fi
    if [[ ! -x "$ACTIVE" ]]; then
        if [[ -f "$ACTIVE" && ! -e "$DISABLED" ]]; then
            mv -- "$ACTIVE" "$DISABLED" || true
        fi
        fail "RainbowBorders.sh is not executable; enable operation was rolled back."
        return 1
    fi
    if refresh_borders; then
        return 0
    fi
    if [[ -f "$ACTIVE" && ! -e "$DISABLED" ]]; then
        mv -- "$ACTIVE" "$DISABLED" || {
            fail "Startup failed and rollback to the disabled state failed."
            return 1
        }
    fi
    fail "Rainbow Borders startup failed; disabled state was restored."
    return 1
}

case "${1:-toggle}" in
    --disable) disable_borders ;;
    --enable) enable_borders ;;
    toggle)
        if [[ -e "$ACTIVE" ]]; then
            disable_borders
        elif [[ -e "$DISABLED" ]]; then
            enable_borders
        else
            fail "Cannot toggle: neither active script nor managed disabled copy exists."
            exit 1
        fi
        ;;
    *)
        fail "Usage: $0 [toggle|--enable|--disable]"
        exit 2
        ;;
esac

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
    local moved_to_disabled=0

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
        moved_to_disabled=1
    elif [[ ! -f "$DISABLED" ]]; then
        fail "Neither the active script nor its managed disabled copy exists."
        return 1
    fi
    if hyprctl reload >/dev/null 2>&1; then
        return 0
    fi
    if ((moved_to_disabled)); then
        mv -- "$DISABLED" "$ACTIVE" || {
            fail "Reload failed and rollback could not restore the active script."
            return 1
        }
        fail "Hyprland reload failed; the previous active state was restored."
    else
        fail "Hyprland reload failed; the existing disabled state was preserved."
    fi
    return 1
}

enable_borders() {
    local restored_from_disabled=0

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
        restored_from_disabled=1
    fi
    if [[ ! -x "$ACTIVE" ]]; then
        if ((restored_from_disabled)); then
            mv -- "$ACTIVE" "$DISABLED" || true
        fi
        fail "RainbowBorders.sh is not executable; enable operation was rolled back where applicable."
        return 1
    fi
    if refresh_borders; then
        return 0
    fi
    if ((restored_from_disabled)); then
        mv -- "$ACTIVE" "$DISABLED" || {
            fail "Startup failed and rollback to the disabled state failed."
            return 1
        }
        fail "Rainbow Borders startup failed; the previous disabled state was restored."
    else
        fail "Rainbow Borders refresh failed; the existing active state was preserved."
    fi
    return 1
}

set_mode() {
    local mode="$1"
    local restored_from_disabled=0
    local backup=""
    local current_mode=""

    case "$mode" in
        wallust_random|rainbow|gradient_flow) ;;
        *)
            fail "Unsupported mode '$mode'; allowed modes are wallust_random, rainbow, and gradient_flow."
            return 2
            ;;
    esac

    if [[ -e "$ACTIVE" && -e "$DISABLED" ]]; then
        fail "Both active and disabled scripts exist; state is inconsistent and no files were changed."
        return 1
    fi
    if [[ ! -e "$ACTIVE" ]]; then
        [[ -f "$DISABLED" ]] || {
            fail "No functional RainbowBorders.sh exists; the archival .bak.sh template is not a fallback."
            return 1
        }
        mv -- "$DISABLED" "$ACTIVE" || {
            fail "Could not restore the managed disabled script."
            return 1
        }
        restored_from_disabled=1
    fi
    [[ -x "$ACTIVE" ]] || {
        if ((restored_from_disabled)); then mv -- "$ACTIVE" "$DISABLED" || true; fi
        fail "RainbowBorders.sh is not executable; mode change was rolled back."
        return 1
    }

    current_mode="$(sed -nE 's/^EFFECT_TYPE="?([^"]*)"?$/\1/p' "$ACTIVE" | head -n1)"
    [[ -n "$current_mode" ]] || {
        if ((restored_from_disabled)); then mv -- "$ACTIVE" "$DISABLED" || true; fi
        fail "RainbowBorders.sh has no readable EFFECT_TYPE assignment."
        return 1
    }

    backup="$(mktemp "${ACTIVE}.gup.XXXXXX")" || {
        if ((restored_from_disabled)); then mv -- "$ACTIVE" "$DISABLED" || true; fi
        fail "Could not allocate a same-directory rollback copy."
        return 1
    }
    if ! cp -p -- "$ACTIVE" "$backup"; then
        rm -f -- "$backup"
        if ((restored_from_disabled)); then mv -- "$ACTIVE" "$DISABLED" || true; fi
        fail "Could not preserve the current mode before changing it."
        return 1
    fi
    if ! sed -i "s/^EFFECT_TYPE=.*/EFFECT_TYPE=\"$mode\"/" "$ACTIVE"; then
        mv -- "$backup" "$ACTIVE" || true
        if ((restored_from_disabled)); then mv -- "$ACTIVE" "$DISABLED" || true; fi
        fail "Could not update EFFECT_TYPE; previous mode/state was restored where possible."
        return 1
    fi

    if refresh_borders; then
        rm -f -- "$backup"
        return 0
    fi

    if ! mv -- "$backup" "$ACTIVE"; then
        fail "Mode refresh failed and the previous script could not be restored."
        return 1
    fi
    if ((restored_from_disabled)); then
        mv -- "$ACTIVE" "$DISABLED" || {
            fail "Mode refresh failed and the original disabled state could not be restored."
            return 1
        }
    fi
    fail "Mode refresh failed; the previous mode/state was restored."
    return 1
}

case "${1:-toggle}" in
    --disable) disable_borders ;;
    --enable) enable_borders ;;
    --mode)
        [[ $# -eq 2 ]] || { fail "Usage: $0 --mode wallust_random|rainbow|gradient_flow"; exit 2; }
        set_mode "$2"
        ;;
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
        fail "Usage: $0 [toggle|--enable|--disable|--mode wallust_random|rainbow|gradient_flow]"
        exit 2
        ;;
esac

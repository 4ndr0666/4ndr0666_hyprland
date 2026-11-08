#!/usr/bin/env bash

# Return success when the host identifies itself as Arch Linux or as an
# Arch-family derivative through ID_LIKE. Arguments override environment
# values so this predicate can be tested without mutating /etc/os-release.
is_arch_family() {
    local id="${1:-${ID:-}}"
    local id_like="${2:-${ID_LIKE:-}}"
    local token

    [[ "$id" == "arch" ]] && return 0

    for token in $id_like; do
        [[ "$token" == "arch" ]] && return 0
    done

    return 1
}

arch_family_name() {
    local id="${1:-${ID:-}}"
    local id_like="${2:-${ID_LIKE:-}}"

    if [[ "$id" == "arch" ]]; then
        printf '%s\n' 'arch'
        return 0
    fi

    printf '%s\n' "${id:-${id_like:-unknown}}"
}

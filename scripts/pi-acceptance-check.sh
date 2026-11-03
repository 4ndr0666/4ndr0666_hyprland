#!/usr/bin/env bash
# Read-only rebuilt-Pi acceptance snapshot. No sudo, installs or service changes.
set -Eeuo pipefail

record() {
    local name=$1 rc=0
    shift
    command timeout --kill-after=5s 30 "$@" > "$out/$name.stdout" 2> "$out/$name.stderr" || rc=$?
    printf '%s\t%s\t' "$name" "$rc" >> "$out/commands.tsv"
    printf '%q ' "$@" >> "$out/commands.tsv"
    printf '\n' >> "$out/commands.tsv"
}

main() {
    (( EUID != 0 )) || { printf 'Run as your Pi login user, without sudo.\n' >&2; return 21; }
    [[ $(command uname -m) == aarch64 ]] || { printf 'Run this on the rebuilt AArch64 Pi.\n' >&2; return 20; }
    umask 077
    export GIT_OPTIONAL_LOCKS=0 GIT_NO_LAZY_FETCH=1 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    out=$(command mktemp -d /tmp/pi-acceptance.XXXXXX)
    printf 'Evidence directory: %s\n' "$out"
    printf 'probe\texit_code\tcommand\n' > "$out/commands.tsv"
    record kernel uname -mr
    record os cat /etc/os-release
    [[ ! -r /proc/device-tree/model ]] || record model cat /proc/device-tree/model
    record packages pacman -Q
    record services systemctl --no-pager is-active systemd-networkd systemd-resolved wpa_supplicant@wlan0 NetworkManager
    record user-manager systemctl --user --no-pager is-system-running
    record space df -h / /boot
    {
        printf 'session_type=%s\n' "${XDG_SESSION_TYPE:-unset}"
        [[ -z ${WAYLAND_DISPLAY:-} ]] || printf 'wayland_display_present=yes\n'
        [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} ]] || printf 'dbus_session_address_present=yes\n'
    } > "$out/session.txt"
    if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        record compositor hyprctl version
        record monitors hyprctl -j monitors
    fi
    local repo i=0
    for repo in "$HOME/git/4ndr0666_hyprland" "$HOME/4ndr0666_hyprland" "$HOME/arch-pi-builder"; do
        [[ -d "$repo/.git" || -f "$repo/.git" ]] || continue
        i=$((i+1))
        printf '%s\n' "$repo" > "$out/source-$i.path"
        record "source-$i-pins" git -c core.fsmonitor=false -c core.hooksPath=/dev/null -C "$repo" rev-parse HEAD 'HEAD^{tree}' --is-shallow-repository
        record "source-$i-refs" git -C "$repo" show-ref --head
        record "source-$i-status" git -c core.fsmonitor=false -c core.hooksPath=/dev/null -C "$repo" status --porcelain=v1 --untracked-files=normal
    done
    printf 'repositories_found=%s\n' "$i" > "$out/source-discovery.txt"
    for repo in "$HOME/.config/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.conf"; do
        [[ ! -f "$repo" ]] || command sha256sum -- "$repo" >> "$out/config-pins.txt"
    done
    (
        cd "$out"
        command find . -maxdepth 1 -type f ! -name SHA256SUMS -print0 |
            command sort -z | command xargs -0 sha256sum > SHA256SUMS
    )
    command tar -czf "$out.tar.gz" -C "$out" .
    command sha256sum "$out.tar.gz"
    printf 'Return the printed archive and SHA256. Missing packages/session are findings, not certification.\n'
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi

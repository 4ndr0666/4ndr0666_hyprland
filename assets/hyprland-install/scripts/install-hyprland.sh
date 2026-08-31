#!/bin/bash
# /* ---- https://github.com/4ndr0666 ---- */

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd -- "${SCRIPT_DIR}/../../../install-scripts/core" && pwd)"
source "${CORE_DIR}/packages.sh"
package_core_init

OK="$(printf '\033[32m[OK]\033[0m')"
ERROR="$(printf '\033[31m[ERROR]\033[0m')"
NOTE="$(printf '\033[33m[NOTE]\033[0m')"
ORANGE="$(printf '\033[38;5;214m')"
RESET="$(printf '\033[0m')"

packages=(aquamarine hyprutils hyprcursor hyprwayland-scanner hyprgraphics hyprlang hyprland-protocols hyprland-qt-support hyprland-qtutils hyprland hyprlock hypridle xdg-desktop-portal-hyprland hyprpolkitagent)

printf '\n%.0s' {1..2}
printf '%s Installing %snon-git Hyprland%s...\n' "$NOTE" "$ORANGE" "$RESET"

package_install "${packages[@]}" || {
    printf '%s Failed to install the non-git Hyprland package set.\n' "$ERROR" >&2
    exit 1
}

printf '%s Done. Exit Hyprland and re-login to activate the installation.\n' "$OK"

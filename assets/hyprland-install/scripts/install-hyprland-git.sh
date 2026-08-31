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

packages=(hyprutils-git hyprcursor-git hyprwayland-scanner-git aquamarine-git hyprgraphics-git hyprlang-git hyprland-protocols-git hyprland-qt-support-git hyprland-qtutils-git hyprland-git hyprlock-git hypridle-git xdg-desktop-portal-hyprland-git hyprpolkitagent-git)

printf '\n%.0s' {1..2}
printf '%s Installing %sgit Hyprland%s...\n' "$NOTE" "$ORANGE" "$RESET"

package_install_aur "${packages[@]}" || {
    printf '%s Failed to install the git Hyprland package set.\n' "$ERROR" >&2
    exit 1
}

printf '%s Done. Exit Hyprland and re-login to activate the installation.\n' "$OK"

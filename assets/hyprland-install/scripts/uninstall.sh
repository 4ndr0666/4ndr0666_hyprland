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

packages=(
aquamarine aquamarine-git
hyprutils hyprutils-git
hyprcursor hyprcursor-git
hyprwayland-scanner hyprwayland-scanner-git
hyprgraphics hyprgraphics-git
hyprlang hyprlang-git
hyprland-protocols hyprland-protocols-git
hyprland-qt-support hyprland-qt-support-git
hyprland-qtutils hyprland-qtutils-git
hyprland hyprland-git
hyprlock hyprlock-git
hypridle hypridle-git
xdg-desktop-portal-hyprland xdg-desktop-portal-hyprland-git
hyprpolkitagent hyprpolkitagent-git
)

printf '\n%s Removing Hyprland packages including -git versions\n' "$NOTE"
package_remove "${packages[@]}" || {
    printf '%s Failed to remove one or more Hyprland packages.\n' "$ERROR" >&2
    exit 1
}

# Remove the portal configuration that can conflict with the replacement package.
sudo rm -f /usr/share/xdg-desktop-portal/hyprland-portals.conf

printf '%s All specified Hyprland packages have been removed.\n' "$OK"

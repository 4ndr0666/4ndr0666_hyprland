#!/usr/bin/env bash
# Golden Unit: canonical package manifest alignment.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT/install-scripts/core/package-manifest.sh"
INSTALLER="$ROOT/install-scripts/01-hypr-pkgs.sh"
BASE="$ROOT/install-scripts/00-base.sh"
PIPEWIRE="$ROOT/install-scripts/pipewire.sh"
FONTS="$ROOT/install-scripts/fonts.sh"
HYPRLAND="$ROOT/install-scripts/hyprland.sh"
FINAL_CHECK="$ROOT/install-scripts/02-Final-Check.sh"

bash -n "$MANIFEST"
bash -n "$INSTALLER"
bash -n "$BASE"
bash -n "$PIPEWIRE"
bash -n "$FONTS"
bash -n "$HYPRLAND"
bash -n "$FINAL_CHECK"

# The canonical manifest must contain the current wallpaper provider and must
# not retain the retired provider under any canonical package role.
grep -Fqx '  awww' <(sed -n '/^AUR_PACKAGES=(/,/^)/p' "$MANIFEST")
! grep -Fq 'swww' "$MANIFEST"

# Packages absent from official Arch Linux ARM repositories must use the AUR helper.
AUR_SECTION="$(sed -n '/^AUR_PACKAGES=(/,/^)/p' "$MANIFEST")"
FONT_AUR_SECTION="$(sed -n '/^FONT_AUR_PACKAGES=(/,/^)/p' "$MANIFEST")"
FONT_SECTION="$(sed -n '/^FONT_PACKAGES=(/,/^)/p' "$MANIFEST")"
grep -Fqx '  wlogout' <<< "$AUR_SECTION"
! grep -Fqx '  wlogout' <(sed -n '/^CORE_PACKAGES=(/,/^)/p' "$MANIFEST")
grep -Fqx '  ttf-victor-mono' <<< "$FONT_AUR_SECTION"
! grep -Fqx '  ttf-victor-mono' <<< "$FONT_SECTION"
grep -Fq 'package_install_aur "${FONT_AUR_PACKAGES[@]}"' "$FONTS"
grep -Fq 'package_install_aur "${AUR_PACKAGES[@]}"' "$INSTALLER"
source "$MANIFEST"
for package in wlogout ttf-victor-mono; do
  printf '%s\n' "${CANONICAL_BASELINE_AUR_PACKAGES[@]}" | grep -Fqx -- "$package"
done

# The graphical initializer owns these mandatory runtime dependencies; they
# must be installed by the core path, not hidden behind an optional selection.
CORE_SECTION="$(sed -n '/^CORE_PACKAGES=(/,/^)/p' "$MANIFEST")"
for package in dbus psmisc waybar xdg-desktop-portal xdg-desktop-portal-hyprland; do
  grep -Fqx "  $package" <<< "$CORE_SECTION" ||
    { printf '[FAIL] Mandatory graphical runtime package is not in CORE_PACKAGES: %s\n' "$package" >&2; exit 1; }
done

XDPH="$ROOT/install-scripts/xdph.sh"
OPTIONAL_PORTAL_SECTION="$(sed -n '/^XDG_PORTAL_PACKAGES=(/,/^)/p' "$XDPH")"
! grep -Fqx '  xdg-desktop-portal-hyprland' <<< "$OPTIONAL_PORTAL_SECTION"
grep -Fqx '  xdg-desktop-portal-gtk' <<< "$OPTIONAL_PORTAL_SECTION"
grep -Fq "xdph 'Install GTK portal integration and test support' OFF" "$ROOT/install.sh"

# Mandatory package modules must consume the single manifest rather than
# carrying independent copies of the canonical package inventory.
for file in "$INSTALLER" "$BASE" "$PIPEWIRE" "$FONTS" "$HYPRLAND" "$FINAL_CHECK"; do
  grep -Fq 'core/package-manifest.sh' "$file"
done

! grep -Eq '^([[:space:]]*)(bc|cliphist|curl|grim|awww|wallust|pipewire|hyprland|noto-fonts)$' "$INSTALLER"
! grep -Eq '^([[:space:]]*)(bc|cliphist|curl|grim|awww|wallust|pipewire|hyprland|noto-fonts)$' "$FINAL_CHECK"

# The active network launcher imports PyGObject. Replay the actual package
# module with all existing requests satisfied except that Python provider.
grep -Fqx 'import gi' "$ROOT/config/hypr/UserScripts/RofiNetwork.sh"
grep -Fq "gi.require_version('NM', '1.0')" "$ROOT/config/hypr/UserScripts/RofiNetwork.sh"
grep -Fq '/RofiNetwork.sh' "$ROOT/config/hypr/configs/Keybinds.lua"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/gup-network-provider.XXXXXX")"
trap 'rm -rf -- "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/install-scripts/core" "$FIXTURE/bin"
cp -- "$INSTALLER" "$FIXTURE/install-scripts/01-hypr-pkgs.sh"
cp -- "$FINAL_CHECK" "$FIXTURE/install-scripts/02-Final-Check.sh"
cp -- "$MANIFEST" "$ROOT/install-scripts/core/packages.sh" "$FIXTURE/install-scripts/core/"
printf '%s\n' "${CANONICAL_BASELINE_PACKAGES[@]}" "${CANONICAL_BASELINE_AUR_PACKAGES[@]}" |
  grep -Fvx -- python-gobject > "$FIXTURE/installed"
: > "$FIXTURE/requests"
cat > "$FIXTURE/bin/pacman" <<'STUB'
#!/usr/bin/env bash
set -Eeuo pipefail
case "${1:-}" in
  -Q) grep -Fqx -- "${@: -1}" "$FAKE_PACMAN_STATE" ;;
  -S)
    while (($#)) && [[ "$1" != -- ]]; do shift; done
    [[ "${1:-}" == -- ]] || exit 64
    shift
    printf '%s\n' "$@" >> "$FAKE_PACMAN_STATE"
    printf '%s\n' "$@" >> "$FAKE_PACMAN_REQUESTS"
    ;;
  *) exit 64 ;;
esac
STUB
printf '#!/usr/bin/env bash\nexec "$@"\n' > "$FIXTURE/bin/sudo"
printf '#!/usr/bin/env bash\nexit 64\n' > "$FIXTURE/bin/yay"
chmod +x "$FIXTURE/bin/"*
if env PATH="$FIXTURE/bin:$PATH" FAKE_PACMAN_STATE="$FIXTURE/installed" \
  LOG="$FIXTURE/precheck.log" PACKAGE_MANIFEST="$FIXTURE/owned" \
  timeout 60 bash "$FIXTURE/install-scripts/02-Final-Check.sh" > "$FIXTURE/precheck-output.log" 2>&1; then
  printf '[FAIL] Final-check accepted the missing GI provider.\n' >&2
  exit 1
fi
grep -Fq 'Missing canonical baseline packages: python-gobject' "$FIXTURE/precheck-output.log"
for attempt in first repeat; do
  env PATH="$FIXTURE/bin:$PATH" FAKE_PACMAN_STATE="$FIXTURE/installed" \
    FAKE_PACMAN_REQUESTS="$FIXTURE/requests" PACKAGE_MANIFEST="$FIXTURE/owned" \
    timeout 60 bash "$FIXTURE/install-scripts/01-hypr-pkgs.sh" > "$FIXTURE/$attempt.log" 2>&1
  [[ "$(cat "$FIXTURE/requests")" == python-gobject ]] ||
    { printf '[FAIL] Actual core module did not provision the missing GI provider exactly once.\n' >&2; exit 1; }
  [[ "$(cat "$FIXTURE/owned")" == python-gobject ]] ||
    { printf '[FAIL] GI provider ownership is missing or pre-existing packages were claimed.\n' >&2; exit 1; }
done
env PATH="$FIXTURE/bin:$PATH" FAKE_PACMAN_STATE="$FIXTURE/installed" \
  LOG="$FIXTURE/postcheck.log" PACKAGE_MANIFEST="$FIXTURE/owned" \
  timeout 60 bash "$FIXTURE/install-scripts/02-Final-Check.sh" > "$FIXTURE/postcheck-output.log" 2>&1

printf '%s\n' 'canonical-package-manifest: PASS'

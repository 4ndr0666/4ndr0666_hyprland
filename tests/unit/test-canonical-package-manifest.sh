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

# Mandatory package modules must consume the single manifest rather than
# carrying independent copies of the canonical package inventory.
for file in "$INSTALLER" "$BASE" "$PIPEWIRE" "$FONTS" "$HYPRLAND" "$FINAL_CHECK"; do
  grep -Fq 'core/package-manifest.sh' "$file"
done

! grep -Eq '^([[:space:]]*)(bc|cliphist|curl|grim|awww|wallust|pipewire|hyprland|noto-fonts)$' "$INSTALLER"
! grep -Eq '^([[:space:]]*)(bc|cliphist|curl|grim|awww|wallust|pipewire|hyprland|noto-fonts)$' "$FINAL_CHECK"

printf '%s\n' 'canonical-package-manifest: PASS'

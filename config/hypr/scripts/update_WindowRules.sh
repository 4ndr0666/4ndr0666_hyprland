#!/usr/bin/env bash
# Script to update or verify WindowRules.lua for Hyprland >= 0.53

set -Eeuo pipefail

CONFIGS_DIR="$HOME/.config/hypr/configs"
TARGET_FILE="$CONFIGS_DIR/WindowRules.lua"
V3_FILE="$CONFIGS_DIR/WindowRules-config-v3.lua"

if [[ ! -f "$V3_FILE" ]]; then
  if [[ -f "$TARGET_FILE" ]] && grep -Fq 'hl.window_rule(' "$TARGET_FILE"; then
    echo "WindowRules.lua already uses the native Lua window_rule schema."
    exit 0
  fi
  echo "Error: Source configuration file not found: $V3_FILE" >&2
  exit 1
fi

get_hyprland_version() {
  local ver="0.0.0"
  local raw_ver=""

  if command -v hyprctl &>/dev/null; then
    raw_ver=$(hyprctl version 2>/dev/null | grep "Tag:" | cut -d 'v' -f2 || true)
  fi

  if [ -z "$raw_ver" ] && command -v Hyprland &>/dev/null; then
    raw_ver=$(Hyprland --version 2>/dev/null | grep "Tag:" | cut -d 'v' -f2 | awk '{print $1}' || true)
  fi

  if [ -n "$raw_ver" ]; then
    ver=$(echo "$raw_ver" | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?' || true)
  fi

  if [ -z "$ver" ]; then
    echo "0.0.0"
  else
    echo "$ver"
  fi
}

VERSION=$(get_hyprland_version)
REQUIRED_VER="0.53"

SMALLEST=$(printf '%s\n' "$REQUIRED_VER" "$VERSION" | sort -V | head -n1)

if [ "$SMALLEST" = "$REQUIRED_VER" ]; then
  echo "Version $VERSION >= $REQUIRED_VER. Updating WindowRules config..."
  if [ -f "$TARGET_FILE" ]; then
    echo "Backing up existing WindowRules.lua to WindowRules.lua.bak"
    mv "$TARGET_FILE" "$TARGET_FILE.bak"
  fi
  cp "$V3_FILE" "$TARGET_FILE"

  if command -v hyprctl &>/dev/null; then
    if hyprctl instances &>/dev/null; then
      echo "Reloading Hyprland..."
      hyprctl reload
    fi
  fi
else
  echo "Version $VERSION < $REQUIRED_VER. No update needed."
fi

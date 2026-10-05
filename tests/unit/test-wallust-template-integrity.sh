#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WALLUST="$ROOT/config/wallust/wallust.toml"
TEMPLATE_DIR="$ROOT/config/wallust/templates"

[[ -f "$WALLUST" ]] || { printf '[FAIL] Wallust configuration is missing.\n' >&2; exit 1; }
[[ -d "$TEMPLATE_DIR" ]] || { printf '[FAIL] Wallust template directory is missing.\n' >&2; exit 1; }

mapfile -t templates < <(
  awk -F"'" '/^[[:alnum:]_-]+\.template[[:space:]]*=/ {print $2}' "$WALLUST"
)

(${#templates[@]} > 0) || { printf '[FAIL] Wallust declares no active templates.\n' >&2; exit 1; }

for template in "${templates[@]}"; do
  [[ -f "$TEMPLATE_DIR/$template" ]] || {
    printf '[FAIL] Active Wallust template is missing: %s\n' "$template" >&2
    exit 1
  }
done

! grep -Fq "zathura.template = 'colors-zathura'" "$WALLUST"

printf '%s\n' "Wallust active-template integrity boundary: PASS (${#templates[@]} templates)"

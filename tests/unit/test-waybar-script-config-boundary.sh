#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/config/hypr/scripts/WaybarScripts.sh"

! grep -Fq 'eval "$config_content"' "$FILE"
! grep -Fq 'eval "$files &' "$FILE"
grep -Fq 'read_lua_command()' "$FILE"
grep -Fq 'validate_command_name()' "$FILE"
grep -Fq '"$files" &' "$FILE"
grep -Fq '"$term" &' "$FILE"

tmp_home="$(mktemp -d)"
trap 'rm -rf -- "$tmp_home"' EXIT
mkdir -p "$tmp_home/.config/hypr/UserConfigs" "$tmp_home/bin"
cp "$FILE" "$tmp_home/waybar-script.sh"
chmod +x "$tmp_home/waybar-script.sh"

cat > "$tmp_home/.config/hypr/UserConfigs/01-UserDefaults.lua" <<'EOF'
local term = "fake-terminal"
local files = "fake-files"
local search_engine = "https://example.invalid/search?text={}"
EOF
cat > "$tmp_home/bin/fake-terminal" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' terminal > "$MARKER"
EOF
cat > "$tmp_home/bin/fake-files" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' files > "$MARKER"
EOF
chmod +x "$tmp_home/bin/fake-terminal" "$tmp_home/bin/fake-files"

MARKER="$tmp_home/marker"
HOME="$tmp_home" PATH="$tmp_home/bin:$PATH" MARKER="$MARKER" "$tmp_home/waybar-script.sh" --term
sleep 0.1
grep -Fxq terminal "$MARKER"

cat > "$tmp_home/.config/hypr/UserConfigs/01-UserDefaults.lua" <<'EOF'
local term = "fake-terminal; printf injected > /tmp/gup-injected"
local files = "fake-files"
local search_engine = "https://example.invalid/search?text={}"
EOF
if HOME="$tmp_home" PATH="$tmp_home/bin:$PATH" MARKER="$MARKER" "$tmp_home/waybar-script.sh" --term; then
  printf '%s\n' 'malicious command value was accepted' >&2
  exit 1
fi

printf '%s\n' 'Waybar config execution boundary: PASS'

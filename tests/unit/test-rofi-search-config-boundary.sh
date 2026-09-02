#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/config/hypr/UserScripts/RofiSearch.sh"

! grep -Fq 'eval "$config_content"' "$FILE"
grep -Fq 'read_lua_search_engine()' "$FILE"
grep -Fq 'Search_Engine="$(read_lua_search_engine)"' "$FILE"
grep -Fq 'xdg-open "${Search_Engine}${encoded_query}"' "$FILE"
grep -Fq '01-UserDefaults.lua' "$FILE"
! grep -Fq '01-UserDefaults.conf' "$FILE"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf -- "$TMP_HOME"' EXIT
mkdir -p "$TMP_HOME/.config/hypr/UserConfigs" "$TMP_HOME/.config/rofi" "$TMP_HOME/bin"
cp "$FILE" "$TMP_HOME/rofi-search.sh"
chmod +x "$TMP_HOME/rofi-search.sh"

cat > "$TMP_HOME/.config/hypr/UserConfigs/01-UserDefaults.lua" <<'EOF'
local term = "kitty"
local files = "thunar"
local search_engine = "https://example.invalid/search?text={}"
EOF

cat > "$TMP_HOME/bin/jq" <<'EOF'
#!/usr/bin/env bash
cat
EOF
cat > "$TMP_HOME/bin/rofi" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'gup test query'
EOF
cat > "$TMP_HOME/bin/xdg-open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" > "$OPEN_TARGET"
EOF
cat > "$TMP_HOME/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat > "$TMP_HOME/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP_HOME/bin/jq" "$TMP_HOME/bin/rofi" "$TMP_HOME/bin/xdg-open" "$TMP_HOME/bin/pgrep" "$TMP_HOME/bin/notify-send"

OPEN_TARGET="$TMP_HOME/open-target"
HOME="$TMP_HOME" PATH="$TMP_HOME/bin:$PATH" OPEN_TARGET="$OPEN_TARGET" "$TMP_HOME/rofi-search.sh"
sleep 0.1
grep -Fxq 'https://example.invalid/search?text={}%0Agup%20test%20query' "$OPEN_TARGET"

cat > "$TMP_HOME/.config/hypr/UserConfigs/01-UserDefaults.lua" <<'EOF'
local term = "kitty"
local files = "thunar"
local search_engine = "https://example.invalid/search?text={}$(touch /tmp/gup-injected)"
EOF
if HOME="$TMP_HOME" PATH="$TMP_HOME/bin:$PATH" OPEN_TARGET="$OPEN_TARGET" "$TMP_HOME/rofi-search.sh"; then
  printf '%s\n' 'malicious search-engine value was accepted' >&2
  exit 1
fi

if [[ -e /tmp/gup-injected ]]; then
  rm -f -- /tmp/gup-injected
  printf '%s\n' 'shell injection side effect occurred' >&2
  exit 1
fi

printf '%s\n' 'Rofi search config execution boundary: PASS'

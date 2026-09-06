#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/config/hypr/scripts/WaybarCava.sh"
SANDBOX="$(mktemp -d)"
trap 'rm -rf -- "$SANDBOX"' EXIT INT TERM HUP

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[[ -f "$SCRIPT" ]] || fail "WaybarCava.sh is missing"
grep -Fq 'waybar-cava.pid' "$SCRIPT" || fail "Cava pidfile contract is missing"
grep -Fq 'mktemp "$RUNTIME_DIR/waybar-cava.' "$SCRIPT" || fail "Cava temporary configuration contract is missing"
grep -Fq 'trap cleanup EXIT INT TERM' "$SCRIPT" || fail "Cava cleanup trap is missing"
grep -Fq 'exec cava -p "$config_file" | sed -u "$dict"' "$SCRIPT" || fail "Cava output pipeline is not authoritative"

mkdir -p "$SANDBOX/bin" "$SANDBOX/runtime"
cat >"$SANDBOX/bin/cava" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
config=""
while (($#)); do
    case "$1" in
        -p) config="$2"; shift 2 ;;
        *) shift ;;
    esac
done
[[ -f "$config" ]] || exit 1
printf '01234567\n'
EOF
chmod 755 "$SANDBOX/bin/cava"

output="$(PATH="$SANDBOX/bin:$PATH" XDG_RUNTIME_DIR="$SANDBOX/runtime" bash "$SCRIPT")" || fail "Cava lifecycle fixture failed"
[[ "$output" == *"▁"* && "$output" == *"█"* ]] || fail "Cava output was not translated through the observable pipeline"
[[ ! -e "$SANDBOX/runtime/waybar-cava.pid" ]] || fail "Cava pidfile survived cleanup"
[[ -z "$(find "$SANDBOX/runtime" -maxdepth 1 -name 'waybar-cava.*.conf' -print -quit)" ]] || fail "Cava temporary configuration survived cleanup"

printf 'PASS: Cava lifecycle creates, streams, and unconditionally cleans runtime state\n'

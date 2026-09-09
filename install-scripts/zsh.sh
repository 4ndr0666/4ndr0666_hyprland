#!/bin/bash
# 💫 https://github.com/4ndr0666 💫 #
# zsh and oh my zsh#

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/core/packages.sh"

LOG="${LOG:-$ROOT_DIR/Install-Logs/install-$(date +%d-%H%M%S)_zsh.log}"
mkdir -p -- "$(dirname "$LOG")"

zsh_pkg=(lsd mercurial zsh zsh-completions)
zsh_pkg2=(fzf)

package_install "${zsh_pkg[@]}"
package_install "${zsh_pkg2[@]}"

OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$OH_MY_ZSH_DIR/custom}"
GIT_COMMAND_TIMEOUT="${GIT_COMMAND_TIMEOUT:-900}"

# Full commit IDs make dependency resolution immutable. Overrides are intended
# only for deliberate dependency updates and must also be full commit IDs.
OH_MY_ZSH_REVISION="${OH_MY_ZSH_REVISION:-97e11051e2f8053b1d694788d1cb4b0dbb1e2365}"
ZSH_AUTOSUGGESTIONS_REVISION="${ZSH_AUTOSUGGESTIONS_REVISION:-85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5}"
ZSH_SYNTAX_HIGHLIGHTING_REVISION="${ZSH_SYNTAX_HIGHLIGHTING_REVISION:-c4d95591843d49838b7ad30081e7aba3135a6703}"

if [[ ! "$GIT_COMMAND_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  printf '[ERROR] GIT_COMMAND_TIMEOUT must be a positive integer number of seconds.\n' >&2
  exit 2
fi
if ! command -v timeout >/dev/null 2>&1; then
  printf '[ERROR] timeout is required for pinned Zsh dependency installation.\n' >&2
  exit 1
fi

clone_pinned() {
  local url="$1" revision="$2" destination="$3"
  local tmp

  if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
    printf '[ERROR] Dependency revision must be a full 40-character commit ID: %s\n' "$revision" >&2
    return 1
  fi
  if [[ "$destination" != "$HOME"/* ]]; then
    printf '[ERROR] Refusing repository destination outside HOME: %s\n' "$destination" >&2
    return 1
  fi
  if [[ -e "$destination" || -L "$destination" ]]; then
    return 0
  fi

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/4ndr0666-zsh-clone.XXXXXX")"
  (
    trap 'rm -rf -- "$tmp"' EXIT
    timeout --signal=TERM --kill-after=30s "${GIT_COMMAND_TIMEOUT}s" \
      git clone --quiet --filter=blob:none --no-checkout "$url" "$tmp"
    timeout --signal=TERM --kill-after=30s "${GIT_COMMAND_TIMEOUT}s" \
      git -C "$tmp" checkout --quiet --detach "$revision"
    actual="$(git -C "$tmp" rev-parse HEAD)"
    if [[ "$actual" != "$revision" ]]; then
      printf '[ERROR] Revision verification failed for %s\n' "$url" >&2
      exit 1
    fi
    rm -rf -- "$tmp/.git"
    mv -- "$tmp" "$destination"
  )
}

install_oh_my_zsh() {
  local url="https://github.com/ohmyzsh/ohmyzsh.git"

  [[ -d "$OH_MY_ZSH_DIR" ]] && return 0
  mkdir -p -- "$(dirname "$OH_MY_ZSH_DIR")"
  clone_pinned "$url" "$OH_MY_ZSH_REVISION" "$OH_MY_ZSH_DIR"
}

install_oh_my_zsh
mkdir -p -- "$ZSH_CUSTOM_DIR/plugins"

clone_pinned "https://github.com/zsh-users/zsh-autosuggestions.git" \
  "$ZSH_AUTOSUGGESTIONS_REVISION" \
  "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
clone_pinned "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
  "$ZSH_SYNTAX_HIGHLIGHTING_REVISION" \
  "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"

install -m 0644 -- "$ROOT_DIR/assets/.zshrc" "$HOME/.zshrc"
install -m 0644 -- "$ROOT_DIR/assets/.zprofile" "$HOME/.zprofile"

if [[ "$(basename -- "${SHELL:-}")" != zsh ]]; then
  chsh -s "$(command -v zsh)"
fi

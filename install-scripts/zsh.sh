#!/usr/bin/env bash
# === 4ndr0666 === #
# zsh and oh-my-zsh

set -Eeuo pipefail

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

clone_pinned() {
  local url="$1" revision="$2" destination="$3"
  local tmp

  [[ "$destination" == "$HOME"/* ]] || {
    printf '[ERROR] Refusing repository destination outside HOME: %s\n' "$destination" >&2
    return 1
  }

  if [[ -e "$destination" ]]; then
    return 0
  fi

  tmp="$(mktemp -d --tmpdir="$(dirname "$destination") .clone.XXXXXX)"
  git clone --quiet --filter=blob:none --no-checkout "$url" "$tmp"
  git -C "$tmp" checkout --quiet --detach "$revision"
  rm -rf -- "$tmp/.git"
  mv -- "$tmp" "$destination"
}

install_oh_my_zsh() {
  local revision="${OH_MY_ZSH_REVISION:-master}"
  local url="https://github.com/ohmyzsh/ohmyzsh.git"

  [[ -d "$OH_MY_ZSH_DIR" ]] && return 0
  mkdir -p -- "$(dirname "$OH_MY_ZSH_DIR")"

  # The default is the repository's named branch for compatibility. Production
  # deployments should set OH_MY_ZSH_REVISION to an immutable commit SHA.
  clone_pinned "$url" "$revision" "$OH_MY_ZSH_DIR"
}

install_oh_my_zsh
mkdir -p -- "$ZSH_CUSTOM_DIR/plugins"

# Pin these repositories with environment variables. Mutable branch names remain
# available for development, while release/preset configurations can supply SHAs.
clone_pinned "https://github.com/zsh-users/zsh-autosuggestions.git" \
  "${ZSH_AUTOSUGGESTIONS_REVISION:-master}" \
  "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
clone_pinned "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
  "${ZSH_SYNTAX_HIGHLIGHTING_REVISION:-master}" \
  "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"

install -m 0644 -- "$ROOT_DIR/assets/.zshrc" "$HOME/.zshrc"
install -m 0644 -- "$ROOT_DIR/assets/.zprofile" "$HOME/.zprofile"

if [[ "$(basename -- "${SHELL:-}")" != zsh ]]; then
  chsh -s "$(command -v zsh)"
fi

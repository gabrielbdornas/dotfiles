#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=setup/lib.sh
source "$SCRIPT_DIR/lib.sh"

echo "===> [3/3] User: configuring user environment..."

PROFILE="$(resolve_profile)"
echo "-----> Profile for this machine: $PROFILE"

# Oh My Zsh. RUNZSH=no CHSH=no so it doesn't hijack this setup shell or
# change the login shell mid-install - that's left as an explicit,
# separate step later if wanted.
#
# `env -u REPO` strips our own exported REPO before running this - Oh My
# Zsh's installer reads a same-named REPO env var itself (to support
# installing from a fork: REPO=${REPO:-ohmyzsh/ohmyzsh}), so without this
# our dotfiles' REPO leaks in and it clones this dotfiles repo instead of
# ohmyzsh/ohmyzsh. See docs/adr/0011.
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "===> Installing Oh My Zsh..."
  env -u REPO RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "-----> Oh My Zsh already installed"
fi

# Zsh plugins
PLUGINS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"

install_plugin() {
  local repo="$1"
  local name
  name="$(basename "$repo")"

  if [ ! -d "$PLUGINS_DIR/$name" ]; then
    echo "===> Installing zsh plugin: $name"
    git clone "https://github.com/$repo.git" "$PLUGINS_DIR/$name"
  else
    echo "-----> zsh plugin $name already installed"
  fi
}

install_plugin "zsh-users/zsh-autosuggestions"
install_plugin "zsh-users/zsh-syntax-highlighting"

# Example dotfiles - the concrete proof that clone -> bootstrap -> system ->
# user -> link_dotfile works end to end. Full old_process/ content migration
# happens later, file by file, reusing link_dotfile.
echo "===> Linking example dotfiles..."
link_dotfile "$REPO_ROOT/config/hypr/keybindings.conf" "$HOME/.config/hypr/keybindings.conf"
link_dotfile "$REPO_ROOT/config/hypr/monitors.conf" "$HOME/.config/hypr/monitors.conf"

# GitHub auth, the SSH key, and the ~/code/$GITHUB_USERNAME workspace (which
# is now where this repo itself lives) all happen in setup.sh instead, before
# the clone - see docs/adr/0012.

# Login-time sync service (async, non-blocking - see setup/sync.sh)
echo "===> Installing dotfiles-sync systemd unit..."
mkdir -p "$HOME/.config/systemd/user"
link_dotfile "$REPO_ROOT/setup/systemd/dotfiles-sync.service" "$HOME/.config/systemd/user/dotfiles-sync.service"
systemctl --user daemon-reload
systemctl --user enable --now dotfiles-sync.service

echo "===> User setup complete"

#!/usr/bin/env bash
set -euo pipefail

# Run with:
# REPO="gabrielbdornas/dotfiles"
# curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/setup.sh" | bash

REPO="${REPO:-gabrielbdornas/dotfiles}"
REPO_URL="https://github.com/$REPO.git"
INSTALL_DIR="$HOME/.dotfiles"

echo "===> Starting setup..."

echo "===> Requesting sudo access..."
sudo -v

# Install git if missing. setup/lib.sh doesn't exist yet at this point in
# the chain (it lives inside the repo we're about to clone), so this is the
# one place package-manager detection has to be inlined rather than shared.
if ! command -v git >/dev/null 2>&1; then
  echo "===> Installing git..."

  if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y git
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --needed --noconfirm git
  else
    echo "Unsupported package manager. Please install git manually."
    exit 1
  fi
fi

# Clone or update repo
if [ ! -d "$INSTALL_DIR" ]; then
  echo "===> Cloning dotfiles..."
  git clone "$REPO_URL" "$INSTALL_DIR"
else
  echo "===> Updating dotfiles..."
  git -C "$INSTALL_DIR" pull
fi

cd "$INSTALL_DIR"

# Run main setup
bash setup/bootstrap.sh

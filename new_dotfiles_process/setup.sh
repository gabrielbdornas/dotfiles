#!/usr/bin/env bash
set -euo pipefail

# TODO: change to gabrielbdornas
# Run with:
# REPO="gabrielbdornass/dotfiles"
# curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/setup.sh" | bash

# TODO: change to gabrielbdornas
REPO="${REPO:-gabrielbdornass/dotfiles}"
REPO_URL="https://github.com/$REPO.git"
INSTALL_DIR="$HOME/.dotfiles"

echo "===> Starting bootstrap..."

echo "===> Requesting sudo access..."
sudo -v

# Install git if missing
if ! command -v git >/dev/null 2>&1; then
  echo "===> Installing git..."

  if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y git
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
bash setup/0-bootstrap.sh

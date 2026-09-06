#!/usr/bin/env bash
set -euo pipefail

echo "===> [0/3] Bootstrap: preparing system..."

# Ask for sudo upfront if needed
if ! sudo -n true 2>/dev/null; then
  echo "===> Requesting sudo access..."
  sudo -v
fi

# Keep sudo alive
while true; do
  sudo -n true
  sleep 60
done >/dev/null 2>&1 &
SUDO_KEEPALIVE_PID=$!

# Ensure cleanup on exit
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# Ensure apt exists
if ! command -v apt >/dev/null 2>&1; then
  echo "Unsupported package manager. Only apt-based systems are supported."
  exit 1
fi

echo "===> Updating package lists..."
sudo apt update

echo "===> Installing base packages..."

BASE_PACKAGES=(
  curl
  ca-certificates
  gnupg
  lsb-release
  zsh
  vim
  unzip
  jq
  tree
)

TO_INSTALL=()

for pkg in "${BASE_PACKAGES[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    TO_INSTALL+=("$pkg")
  fi
done

if [ ${#TO_INSTALL[@]} -gt 0 ]; then
  echo "-----> Installing: ${TO_INSTALL[*]}"
  sudo apt install -y "${TO_INSTALL[@]}"
else
  echo "-----> All packages already installed"
fi

echo "===> Generating locale (en_US.UTF-8)..."
if ! locale -a | grep -qi "en_US\.utf-8"; then
  sudo locale-gen en_US.UTF-8
fi

echo "===> Bootstrap complete"

# Continue
bash setup/1_system.sh
bash setup/2_user.sh

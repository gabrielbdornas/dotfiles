#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup/lib.sh
source "$SCRIPT_DIR/lib.sh"

echo "===> [1/3] Bootstrap: preparing system..."

# setup.sh already checks this before cloning, but bootstrap.sh can also
# run without going through setup.sh first - setup/sync.sh re-runs it
# directly on every login, and it's the entry point for local Docker
# testing too. See docs/adr/0017.
if ! is_omarchy; then
  echo "This only supports Omarchy machines. See docs/adr/0017." >&2
  exit 1
fi

sudo_keepalive

echo "===> Updating package lists..."
sudo pacman -Sy

echo "===> Installing base packages..."
BASE_PACKAGES=(curl ca-certificates gnupg zsh vim unzip jq tree)

TO_INSTALL=()
for pkg in "${BASE_PACKAGES[@]}"; do
  pacman -Qi "$pkg" >/dev/null 2>&1 || TO_INSTALL+=("$pkg")
done

if [ ${#TO_INSTALL[@]} -gt 0 ]; then
  echo "-----> Installing: ${TO_INSTALL[*]}"
  pkg_install "${TO_INSTALL[@]}"
else
  echo "-----> All packages already installed"
fi

echo "===> Generating locale (en_US.UTF-8)..."
if ! locale -a | grep -qi "en_US\.utf-8"; then
  sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  sudo locale-gen
fi

echo "===> Bootstrap complete"

# Continue
bash "$SCRIPT_DIR/system.sh"
bash "$SCRIPT_DIR/user.sh"

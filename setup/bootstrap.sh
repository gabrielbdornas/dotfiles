#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup/lib.sh
source "$SCRIPT_DIR/lib.sh"

echo "===> [1/3] Bootstrap: preparing system..."

sudo_keepalive

DISTRO_MGR="$(detect_distro)"
if [ "$DISTRO_MGR" = "unsupported" ]; then
  echo "Unsupported distro. Only apt and pacman based systems are supported."
  exit 1
fi

echo "===> Updating package lists..."
case "$DISTRO_MGR" in
  apt) sudo apt update ;;
  pacman) sudo pacman -Sy ;;
esac

echo "===> Installing base packages..."

# lsb-release is deliberately not here: detect_distro() reads /etc/os-release
# directly, so nothing needs the lsb_release binary.
BASE_PACKAGES=(
  curl
  ca-certificates
  gnupg
  zsh
  vim
  unzip
  jq
  tree
)

TO_INSTALL=()
for pkg in "${BASE_PACKAGES[@]}"; do
  case "$DISTRO_MGR" in
    apt) dpkg -s "$pkg" >/dev/null 2>&1 || TO_INSTALL+=("$pkg") ;;
    pacman) pacman -Qi "$pkg" >/dev/null 2>&1 || TO_INSTALL+=("$pkg") ;;
  esac
done

if [ ${#TO_INSTALL[@]} -gt 0 ]; then
  echo "-----> Installing: ${TO_INSTALL[*]}"
  pkg_install "${TO_INSTALL[@]}"
else
  echo "-----> All packages already installed"
fi

echo "===> Generating locale (en_US.UTF-8)..."
if ! locale -a | grep -qi "en_US\.utf-8"; then
  case "$DISTRO_MGR" in
    apt)
      sudo locale-gen en_US.UTF-8
      ;;
    pacman)
      sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
      sudo locale-gen
      ;;
  esac
fi

echo "===> Bootstrap complete"

# Continue
bash "$SCRIPT_DIR/system.sh"
bash "$SCRIPT_DIR/user.sh"

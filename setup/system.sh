#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup/lib.sh
source "$SCRIPT_DIR/lib.sh"

echo "===> [2/3] System: installing system-level tools..."

DISTRO_MGR="$(detect_distro)"

# VS Code and its extensions are deliberately not installed here yet -
# that's dotfile/tool content to migrate from old_process/ in a later pass,
# not core infra. GitHub CLI is included because setup/user.sh needs it.
if ! command -v gh >/dev/null 2>&1; then
  echo "===> Installing GitHub CLI..."

  case "$DISTRO_MGR" in
    apt)
      if dpkg -s gitsome >/dev/null 2>&1; then
        echo "-----> Removing conflicting gitsome package..."
        sudo apt remove -y gitsome
      fi

      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg

      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

      sudo apt update
      sudo apt install -y gh
      ;;
    pacman)
      # Arch's package is just called github-cli.
      sudo pacman -S --needed --noconfirm github-cli
      ;;
    *)
      echo "Unsupported package manager. Only apt and pacman based systems are supported."
      exit 1
      ;;
  esac
else
  echo "-----> GitHub CLI already installed"
fi

echo "===> System setup complete"

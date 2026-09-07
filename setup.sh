#!/usr/bin/env bash
set -euo pipefail

# Run with:
# export REPO="yourname/dotfiles" INFISICAL_TOKEN="..." INFISICAL_PROJECT_ID="..." INFISICAL_ENV="home" \
#   && curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/setup.sh" | bash

# No hardcoded defaults on purpose - fail fast with a clear message instead
# of silently doing the wrong thing if these weren't exported before this
# script ran (a plain, non-exported VAR=... in the calling shell does NOT
# reach this process - see docs/adr/0009 for why). See docs/adr/0012 for why
# gh/Infisical/SSH setup all happen here, before the repo is even cloned.
: "${REPO:?REPO is required. Set it, e.g.: export REPO=\"yourname/dotfiles\"}"
: "${INFISICAL_TOKEN:?INFISICAL_TOKEN is required - a machine identity token with read access to your GH_TOKEN secret.}"
: "${INFISICAL_PROJECT_ID:?INFISICAL_PROJECT_ID is required - the Infisical project holding your GH_TOKEN secret.}"
: "${INFISICAL_ENV:?INFISICAL_ENV is required - the Infisical environment name for this machine, e.g. home or work.}"

echo "===> Starting setup..."

echo "===> Requesting sudo access..."
sudo -v

# setup/lib.sh doesn't exist yet at this point (it lives inside the repo
# we're about to clone), so package-manager detection has to be inlined
# here rather than shared - same reasoning as the original git-only version
# of this script, now covering gh/jq/infisical too.
if command -v apt >/dev/null 2>&1; then
  EARLY_PKG_MGR="apt"
elif command -v pacman >/dev/null 2>&1; then
  EARLY_PKG_MGR="pacman"
else
  echo "Unsupported package manager. Only apt and pacman based systems are supported." >&2
  exit 1
fi

early_pkg_install() {
  case "$EARLY_PKG_MGR" in
    apt) sudo env DEBIAN_FRONTEND=noninteractive apt install -y "$@" ;;
    pacman) sudo pacman -S --needed --noconfirm "$@" ;;
  esac
}

if [ "$EARLY_PKG_MGR" = "apt" ]; then
  sudo apt update
else
  sudo pacman -Sy
fi

if ! command -v git >/dev/null 2>&1; then
  echo "===> Installing git..."
  early_pkg_install git
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "===> Installing jq..."
  early_pkg_install jq
fi

# GitHub CLI - same install logic that used to live in setup/system.sh,
# moved here because we need gh authenticated (below) before we know
# $GITHUB_USERNAME, which now determines where the repo itself gets cloned.
if ! command -v gh >/dev/null 2>&1; then
  echo "===> Installing GitHub CLI..."
  case "$EARLY_PKG_MGR" in
    apt)
      if dpkg -s gitsome >/dev/null 2>&1; then
        echo "-----> Removing conflicting gitsome package..."
        sudo env DEBIAN_FRONTEND=noninteractive apt remove -y gitsome
      fi
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt update
      early_pkg_install gh
      ;;
    pacman)
      # Arch's package is just called github-cli.
      early_pkg_install github-cli
      ;;
  esac
fi

# Infisical CLI. apt has an official repo; Arch's official method (`yay -S
# infisical-bin`) needs an AUR helper we don't want to bootstrap just for
# this, so on pacman we install the prebuilt .pkg.tar.zst straight from
# their GitHub releases instead - see docs/adr/0012.
if ! command -v infisical >/dev/null 2>&1; then
  echo "===> Installing Infisical CLI..."
  case "$EARLY_PKG_MGR" in
    apt)
      curl -1sLf 'https://artifacts-cli.infisical.com/setup.deb.sh' | sudo -E bash
      sudo env DEBIAN_FRONTEND=noninteractive apt install -y infisical
      ;;
    pacman)
      ARCH="$(uname -m)"
      case "$ARCH" in
        x86_64) INFISICAL_ARCH="amd64" ;;
        aarch64) INFISICAL_ARCH="arm64" ;;
        *)
          echo "Unsupported architecture for Infisical CLI: $ARCH" >&2
          exit 1
          ;;
      esac
      INFISICAL_PKG_URL="$(curl -fsSL https://api.github.com/repos/Infisical/cli/releases/latest \
        | grep -oE "\"browser_download_url\": *\"[^\"]+linux_${INFISICAL_ARCH}\.pkg\.tar\.zst\"" \
        | sed -E 's/.*"(https:[^"]+)"/\1/')"
      if [ -z "$INFISICAL_PKG_URL" ]; then
        echo "Could not find an Infisical CLI release for linux_${INFISICAL_ARCH}." >&2
        exit 1
      fi
      INFISICAL_PKG_FILE="$(mktemp --suffix=.pkg.tar.zst)"
      curl -fsSL -o "$INFISICAL_PKG_FILE" "$INFISICAL_PKG_URL"
      sudo pacman -U --noconfirm "$INFISICAL_PKG_FILE"
      rm -f "$INFISICAL_PKG_FILE"
      ;;
  esac
fi

# Fetch the GitHub token from Infisical and authenticate gh non-interactively.
# `infisical run` injects secrets from the given project/env as environment
# variables into the wrapped command; capturing `printenv GH_TOKEN` gets us
# just that one value without needing any other secrets it might contain.
if ! gh auth status >/dev/null 2>&1; then
  echo "===> Fetching GitHub token from Infisical..."
  GH_TOKEN="$(infisical run --token="$INFISICAL_TOKEN" --projectId="$INFISICAL_PROJECT_ID" --env="$INFISICAL_ENV" -- printenv GH_TOKEN)"
  if [ -z "$GH_TOKEN" ]; then
    echo "Infisical returned no value for secret GH_TOKEN (project $INFISICAL_PROJECT_ID, env $INFISICAL_ENV)." >&2
    exit 1
  fi
  echo "===> Authenticating GitHub CLI..."
  echo "$GH_TOKEN" | gh auth login --with-token
else
  echo "-----> GitHub CLI already authenticated"
fi

if ! command -v ssh-keygen >/dev/null 2>&1; then
  echo "===> Installing openssh client..."
  case "$EARLY_PKG_MGR" in
    apt) early_pkg_install openssh-client ;;
    pacman) early_pkg_install openssh ;;
  esac
fi

# SSH key: --with-token doesn't generate one the way the old interactive
# `-w` flow did, so it's done explicitly here. The GH_TOKEN secret needs the
# admin:public_key (classic PAT) or "SSH keys" (fine-grained PAT) permission
# for `gh ssh-key add` to succeed - if this fails with a permission error,
# that's the first thing to check.
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY" ]; then
  echo "===> Generating SSH key..."
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "$(whoami)@$(hostname)"
fi

# Pre-accept GitHub's host key non-interactively - without this, the first
# SSH connection below would print the "authenticity of host ... can't be
# established" prompt, which would hang reading from a stdin that's actually
# the curl pipe (same class of bug as docs/adr/0010's debconf fix).
if ! grep -q "github.com" "$HOME/.ssh/known_hosts" 2>/dev/null; then
  mkdir -p "$HOME/.ssh"
  ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
fi

# `gh ssh-key add` errors on a duplicate key rather than no-op-ing; treating
# that specific failure as success is the idempotency check here. Worth
# confirming gh's exact wording hasn't changed if this ever misfires.
GH_SSH_KEY_ADD_ERR="$(mktemp)"
if ! gh ssh-key add "$SSH_KEY.pub" --title "$(hostname)" 2>"$GH_SSH_KEY_ADD_ERR"; then
  if grep -qi "already in use\|already exists" "$GH_SSH_KEY_ADD_ERR"; then
    echo "-----> SSH key already registered with GitHub"
  else
    cat "$GH_SSH_KEY_ADD_ERR" >&2
    rm -f "$GH_SSH_KEY_ADD_ERR"
    exit 1
  fi
fi
rm -f "$GH_SSH_KEY_ADD_ERR"

GITHUB_USERNAME="$(gh api user | jq -r '.login')"
echo "-----> GitHub user: $GITHUB_USERNAME"

INSTALL_DIR="$HOME/code/$GITHUB_USERNAME/dotfiles"
REPO_URL="git@github.com:$REPO.git"

mkdir -p "$(dirname "$INSTALL_DIR")"

# Clone or update repo
if [ ! -d "$INSTALL_DIR" ]; then
  echo "===> Cloning dotfiles..."
  git clone "$REPO_URL" "$INSTALL_DIR"
else
  echo "===> Updating dotfiles..."
  git -C "$INSTALL_DIR" pull
fi

# Recorded so setup/systemd/dotfiles-sync.service can find the repo without
# a hardcoded path - $GITHUB_USERNAME varies per machine, unlike the old
# fixed ~/.dotfiles location. See docs/adr/0012.
mkdir -p "$HOME/.config/dotfiles"
echo "DOTFILES_DIR=\"$INSTALL_DIR\"" > "$HOME/.config/dotfiles/env"

cd "$INSTALL_DIR"

# Run main setup
bash setup/bootstrap.sh

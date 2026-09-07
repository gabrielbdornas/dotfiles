#!/usr/bin/env bash
# Shared helpers sourced by setup/bootstrap.sh, setup/system.sh, setup/user.sh
# and setup/sync.sh. Not meant to be run directly.

# Prints "apt", "pacman", or "unsupported" based on /etc/os-release.
# Deliberately avoids the lsb_release binary - the ID field already answers
# the same question without an extra dependency, and works the same way
# whether or not we're inside WSL.
detect_distro() {
  # shellcheck disable=SC1091
  source /etc/os-release

  case "$ID" in
    arch) echo "pacman" ;;
    debian|ubuntu) echo "apt" ;;
    *)
      case "${ID_LIKE:-}" in
        *arch*) echo "pacman" ;;
        *debian*) echo "apt" ;;
        *) echo "unsupported" ;;
      esac
      ;;
  esac
}

# WSL is an independent axis from distro - a WSL Ubuntu box is still "apt",
# a WSL Arch box is still "pacman". This is the one canonical check for it.
is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

# Installs packages using whichever package manager detect_distro finds.
# Callers handle their own per-distro package-name differences before
# calling this (e.g. gh's Arch package is "github-cli", not "gh").
pkg_install() {
  local mgr
  mgr="$(detect_distro)"

  case "$mgr" in
    apt) sudo apt install -y "$@" ;;
    pacman) sudo pacman -S --needed --noconfirm "$@" ;;
    *)
      echo "Unsupported package manager. Only apt and pacman based systems are supported."
      exit 1
      ;;
  esac
}

# Requests sudo up front (skipping the prompt if credentials are already
# cached) and keeps them alive for the rest of this script's process tree
# via a background loop, cleaned up on exit via trap.
sudo_keepalive() {
  if ! sudo -n true 2>/dev/null; then
    echo "===> Requesting sudo access..."
    sudo -v
  fi

  while true; do
    sudo -n true
    sleep 60
  done >/dev/null 2>&1 &
  SUDO_KEEPALIVE_PID=$!

  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
}

DOTFILES_PROFILE_FILE="$HOME/.config/dotfiles/profile"

# Resolves which profile (e.g. "home"/"work") this machine is: the
# DOTFILES_PROFILE env var if set, otherwise a persisted local file,
# otherwise (only when running interactively) prompts once and persists
# the answer. Persistence matters because setup/sync.sh runs
# non-interactively (from a systemd unit) and has no terminal to prompt on.
resolve_profile() {
  if [ -n "${DOTFILES_PROFILE:-}" ]; then
    echo "$DOTFILES_PROFILE"
    return
  fi

  if [ -f "$DOTFILES_PROFILE_FILE" ]; then
    cat "$DOTFILES_PROFILE_FILE"
    return
  fi

  if [ -t 0 ]; then
    read -r -p "===> Which profile is this machine (e.g. home/work)? " profile
    mkdir -p "$(dirname "$DOTFILES_PROFILE_FILE")"
    echo "$profile" > "$DOTFILES_PROFILE_FILE"
    echo "$profile"
    return
  fi

  echo "home"
}

# Symlinks src -> dest, handling three cases:
#   - dest doesn't exist: create the symlink.
#   - dest is already the correct symlink: no-op.
#   - dest is a real file: back it up first, then symlink.
#
# One extra safety check beyond the basic pattern: if dest is a real file
# whose content differs from src, this does NOT assume the repo silently
# wins. Tools that do atomic writes (write-temp + rename - this includes
# the Omarchy skill, and many editors) replace a symlink with a real file,
# silently detaching it from the repo. When that's detected, the diverged
# file is backed up (so nothing is lost) and a warning is printed instead
# of quietly discarding what might be an intentional recent edit.
# Reconciling which side should win is a manual step for now.
link_dotfile() {
  local src="$1"
  local dest="$2"

  if [ -L "$dest" ]; then
    if [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
      echo "-----> $dest already linked"
      return
    fi
    echo "-----> $dest is a symlink pointing elsewhere, relinking"
    rm "$dest"
  elif [ -e "$dest" ]; then
    if diff -q "$dest" "$src" >/dev/null 2>&1; then
      echo "-----> $dest matches repo content but isn't a symlink yet, relinking"
    else
      echo "-----> WARNING: $dest exists with different content than $src."
      echo "       It was likely a real file (not our symlink) that got edited directly."
      echo "       Backing it up to $dest.backup and linking the repo version anyway -"
      echo "       reconcile the two manually if the backup has changes you want to keep."
    fi
    mv "$dest" "$dest.backup"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "-----> Linked $dest -> $src"
}

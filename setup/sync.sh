#!/usr/bin/env bash
# Called by setup/systemd/dotfiles-sync.service once per login: pulls the
# repo and re-applies bootstrap (already idempotent end to end, so safe to
# run in full again), reporting the result via a desktop notification since
# this runs in the background with no terminal attached.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "dotfiles-sync" "$1"
}

if ! git -C "$REPO_ROOT" pull --ff-only; then
  notify "Failed to pull dotfiles repo - sync aborted."
  exit 1
fi

if ! bash "$SCRIPT_DIR/bootstrap.sh"; then
  notify "Dotfiles sync failed while applying updates."
  exit 1
fi

notify "Dotfiles synced successfully."

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal dotfiles repo, originally forked from Le Wagon's bootcamp dotfiles (`old_process/`) and currently being rewritten into a new, from-scratch setup flow (`setup/`). The two live side by side during the migration — `old_process/` is the legacy, install.sh + symlink-based flow that this repo is moving away from; `setup/` is the new entry point.

## Architecture

### New process (`setup/`, in progress)

Entry point is `setup.sh` at the repo root, meant to be curled and run on a fresh machine:

```bash
curl -fsSL "https://raw.githubusercontent.com/<REPO>/main/setup.sh" | bash
```

It clones/updates this repo into `~/.dotfiles`, then chains into `setup/0_bootstrap.sh`, which in turn runs `setup/1_system.sh` and `setup/2_user.sh` sequentially. The numbered scripts are meant to run in order and represent stages:

- `0_bootstrap.sh` — apt-based OS bootstrap: requests sudo (kept alive via background loop), installs base packages (curl, zsh, vim, jq, tree, etc.), generates the `en_US.UTF-8` locale.
- `1_system.sh` — system-level setup (currently an empty stub, not yet implemented).
- `2_user.sh` — user-level setup (currently an empty stub, not yet implemented).

Note: `setup.sh` currently references `setup/0-bootstrap.sh` (hyphen), while the actual file is `setup/0_bootstrap.sh` (underscore) — check this mismatch before assuming the entry point runs end-to-end.

`0_bootstrap.sh` currently assumes an apt-based system only and exits on other package managers.

### Legacy process (`old_process/`)

The original Le Wagon dotfiles flow, kept for reference while the new process is built out:

- `install.sh` — zsh script that symlinks dotfiles (`aliases`, `gitconfig`, `irbrc`, `pryrc`, `rspec`, `zprofile`, `zshrc`) from the repo into `$HOME` (backing up any pre-existing real file to `.backup` first), installs `zsh-syntax-highlighting`/`zsh-autosuggestions` oh-my-zsh plugins, and symlinks VS Code `settings.json`/`keybindings.json` (path differs for macOS vs Linux vs WSL).
- `git_setup.sh` — interactively sets `git config --global user.name/email`, commits, and adds the `lewagon/dotfiles` upstream remote.
- `aliases`, `gitconfig`, `zshrc`, `zprofile`, `irbrc`, `pryrc`, `rspec`, `config` — the actual dotfiles that get symlinked.

When editing files under `old_process/`, keep in mind it mirrors upstream `lewagon/dotfiles` conventions (see `old_process/README.md`) plus personal additions layered on top (e.g. python venv helpers, `gh`-based repo-creation aliases in `aliases`).

## Working conventions

- There is no build, lint, or test tooling in this repo — it's shell scripts and config files only. Validate changes by reading the shell scripts carefully (`bash -n <script>` for a syntax check) rather than expecting a test suite.
- Scripts use `set -euo pipefail`; keep new scripts consistent with that.
- The `setup/` scripts are meant to be idempotent (e.g. `0_bootstrap.sh` checks `dpkg -s` before installing, and locale generation is conditional) — preserve that property when extending `1_system.sh`/`2_user.sh`.

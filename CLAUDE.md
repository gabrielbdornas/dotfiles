# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal dotfiles repo for **Omarchy machines specifically** (Arch-derived), originally forked from Le Wagon's bootcamp dotfiles (`old_process/`) and rewritten from scratch into `setup/`. The two live side by side: `old_process/` is the legacy, install.sh + symlink-based flow this repo has moved away from; `setup/` is the current, only-supported entry point. Full rationale for every decision below lives in `docs/adr/` — read `docs/adr/README.md` for the index before assuming *why* something is built a certain way.

## Architecture (`setup/`, current process)

Entry point is `setup.sh` at the repo root, meant to be curled and run on a fresh machine:

```bash
export REPO="gabrielbdornas/dotfiles" \
       INFISICAL_TOKEN="<machine identity token>" \
       INFISICAL_PROJECT_ID="<infisical project id>" \
       INFISICAL_ENV="home" \
  && curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/setup.sh" | bash
```

All four env vars must be `export`ed (not just set) since `curl | bash` streams into a new process's stdin — a plain shell variable never reaches it (see `docs/adr/0009`).

`setup.sh` does much more than "just clone the repo" now (see `docs/adr/0012`):
- Checks `/etc/os-release` for `ID=omarchy` and fails fast otherwise — this repo is Omarchy-only, not general Arch and not multi-distro (`docs/adr/0017`, superseding `docs/adr/0002`/`0010`).
- Installs `git`, `jq`, `github-cli`, and the Infisical CLI (via pacman, or a direct `.pkg.tar.zst` download from GitHub releases for Infisical).
- Pulls a `GH_TOKEN` secret out of Infisical and authenticates `gh` non-interactively.
- Generates an SSH key and registers it with GitHub via `gh ssh-key add`.
- Clones/updates this repo into `~/code/$GITHUB_USERNAME/dotfiles` (not a fixed `~/.dotfiles` — the path depends on the authenticated GitHub user, discovered mid-script) and records that path in `~/.config/dotfiles/env` for later use by the sync service.
- Chains into `setup/bootstrap.sh`.

`setup/bootstrap.sh` → `setup/system.sh` → `setup/user.sh`, run in that order:
- `bootstrap.sh` — re-checks `is_omarchy()` (it can also be invoked directly, e.g. by `setup/sync.sh` or Docker testing, not only via `setup.sh`), keeps sudo alive, installs base packages (`curl ca-certificates gnupg zsh vim unzip jq tree`) via pacman, generates the `en_US.UTF-8` locale, then runs `system.sh` and `user.sh`.
- `system.sh` — currently near-empty; `gh` install moved into `setup.sh` since GitHub auth now has to happen before the clone. VS Code + extensions setup is deliberately deferred (`docs/adr/0008`).
- `user.sh` — resolves the machine profile (`resolve_profile`, see below), installs Oh My Zsh (`RUNZSH=no CHSH=no`, with `REPO` stripped via `env -u REPO` so Oh My Zsh's installer doesn't misread this repo's own `REPO` var — `docs/adr/0011`), installs `zsh-autosuggestions`/`zsh-syntax-highlighting`, symlinks the example Omarchy dotfiles under `config/hypr/` via `link_dotfile()` (gated on `is_omarchy()` — `docs/adr/0016`), and installs+enables the `dotfiles-sync` systemd user unit if a usable `systemctl --user` session exists (guarded — containers/minimal environments often lack a session bus, `docs/adr/0014`).

`setup/lib.sh` — shared helpers sourced by the three scripts above and `sync.sh`:
- `is_omarchy()` — checks `/etc/os-release` for `ID=omarchy`; the single source of truth for the Omarchy gate.
- `pkg_install()` — thin `pacman -S --needed --noconfirm` wrapper (no distro branching — Omarchy-only).
- `sudo_keepalive()` — requests sudo once, keeps it alive via a background loop, cleaned up via `trap ... EXIT`.
- `resolve_profile()` — resolves `DOTFILES_PROFILE` (env var → persisted `~/.config/dotfiles/profile` file → interactive prompt if a TTY → `"home"` fallback for non-interactive/no-file cases, e.g. the sync service).
- `link_dotfile()` — symlinks src → dest; no-ops if already correctly linked, relinks if pointing elsewhere, and if dest is a *real* file (possibly diverged, e.g. from an Omarchy migration doing an atomic write that detached the symlink), backs it up to `dest.backup` and links anyway rather than silently discarding or silently keeping stale content (`docs/adr/0006`).

`setup/sync.sh` — invoked by `setup/systemd/dotfiles-sync.service` once per login (async, non-blocking — `docs/adr/0007`): `git pull --ff-only` the repo, re-run `bootstrap.sh` in full (idempotent by design), and report success/failure via `notify-send`.

## Legacy process (`old_process/`)

The original Le Wagon dotfiles flow, kept for reference only — not deleted, not being replicated exactly:

- `install.sh` — zsh script that symlinks dotfiles (`aliases`, `gitconfig`, `irbrc`, `pryrc`, `rspec`, `zprofile`, `zshrc`) from the repo into `$HOME` (backing up any pre-existing real file to `.backup` first), installs `zsh-syntax-highlighting`/`zsh-autosuggestions` oh-my-zsh plugins, and symlinks VS Code `settings.json`/`keybindings.json` (path differs for macOS vs Linux vs WSL).
- `git_setup.sh` — interactively sets `git config --global user.name/email`, commits, and adds the `lewagon/dotfiles` upstream remote.
- `aliases`, `gitconfig`, `zshrc`, `zprofile`, `irbrc`, `pryrc`, `rspec`, `config` — the actual dotfiles that get symlinked.

Migrating this content into `setup/` (file by file, reusing `link_dotfile()`) is explicitly out of scope for the current pass (`docs/adr/0008`) — don't assume it's implicitly wanted.

## Testing (`docker/`)

No unit/integration test suite — this is shell scripts and config files. Validate changes with `bash -n <script>` for a syntax check, careful reading, and:

- `docker/omarchy_test.Dockerfile` approximates an Omarchy machine for testing `setup/` end to end (see `docker/README.md`), including seeding `~/.config/hypr` with Omarchy's real default config to exercise `link_dotfile()`'s collision-safety path. It does **not** run Omarchy's actual installer.
- Full end-to-end test: `docker run --rm -it dotfiles-omarchy-test`, then the same documented curl one-liner inside the container — needs a real Infisical project with a `GH_TOKEN` secret carrying SSH-key-management permission.
- Faster iteration on `bootstrap.sh`/`system.sh`/`user.sh` alone: mount the repo read-only, stub `~/.config/dotfiles/env`, run `bootstrap.sh` directly — see `docker/README.md` for the exact commands. Run it twice to confirm idempotency.
- Known container limitations: no usable `systemctl --user` session (so the sync-service install path only exercises its graceful skip, not the real install), and Arch package signing/keyring behavior is unconfirmed.

## Working conventions

- Every script starts with `set -euo pipefail`; keep new scripts consistent with that. Note `-e` does **not** trigger inside `if condition; then ...` or `&&`/`||` chains — this repo relies on explicit `if ! command; then ...` checks rather than `-e` alone in those spots.
- `setup/` scripts are meant to be fully idempotent end to end (checked via `pacman -Qi`, symlink/content comparisons in `link_dotfile()`, `[ -d ... ]` guards, etc.) — preserve that property when extending any of them, and verify by running twice in the Docker container.
- This repo is Omarchy-only by deliberate decision (`docs/adr/0017`) — do not reintroduce apt/Ubuntu/multi-distro branching without a new ADR revisiting that.
- `docs/adr/` is the source of truth for *why*; keep it up to date when making an architecturally significant change (add a new numbered ADR rather than editing history, mark superseded ones with a strikethrough note in `docs/adr/README.md`, following the existing pattern for 0002/0010/0013).
- `docs/adr/0019` is the last open/unresolved decision (Proposed, deferred): what strategy to use for syncing Omarchy's broader `~/.config` surface (hypr, theme, shell layout) across machines over time, beyond the two example files linked today. Two third-party plugins were identified as candidates but their actual source hasn't been read yet — see that ADR before adding new files under `config/hypr/` on the assumption a general sync story already exists.

# 0008 - This pass is infrastructure only — `old_process/` content migration deferred

## Status

Accepted

## Context

`old_process/` holds years of accumulated, real, working configuration:
`zshrc` (222 lines, WSL detection, `nvm`, custom functions, `cursor`
tooling), `aliases`, a `gitconfig` with a hardcoded identity, VS Code
settings/keybindings, and an SSH `config`. Porting all of it into the new
structure in the same pass as building the structure itself risked
conflating two different kinds of risk: architecture bugs vs. content
migration mistakes.

`main_idea.md` also explicitly asked to build "in parts," starting with
something small (a simple dotfile change) before moving on to bigger
pieces.

## Decision

This pass builds and proves the *infrastructure*: the
`setup.sh`/`bootstrap.sh`/`system.sh`/`user.sh` chain, distro/WSL
detection, the profile mechanism, the Infisical hook point, the safe
symlink helper, and the login-sync service — validated against exactly two
small, real example dotfiles (`config/hypr/keybindings.conf` and
`config/hypr/monitors.conf`), not the full `old_process/` content.

`old_process/` is kept as a living reference — read from occasionally
while migrating, not deleted, and not something the new process is
obligated to replicate exactly.

## Consequences

- After this pass, a fresh machine gets a working shell environment
  (Oh My Zsh + plugins), `gh` set up, a workspace directory, and two real
  Hyprland config files under version control — but not yet your actual
  `zshrc`/`aliases`/`gitconfig`/VS Code/SSH setup. Those still come from
  `old_process/install.sh` (or by hand) until migrated.
- Migration happens incrementally, file by file, each one reusing
  `link_dotfile()` and, where relevant, the profile
  ([0004](0004-machine-profile-via-env-var.md)) and secrets
  ([0005](0005-secrets-via-infisical.md)) mechanisms already in place.
- VS Code + extensions and Oh-My-Zsh-adjacent tooling beyond what's already
  in `user.sh` are explicitly part of that deferred migration, not this
  pass — see `setup/system.sh`'s comment for the specific VS Code
  omission.

> **Update ([0012](0012-authenticate-before-cloning-into-code-dir.md)):**
> "real Infisical-backed secret values" turned out not to wait for content
> migration after all - `gh` authentication via an Infisical-sourced
> `GH_TOKEN` was pulled forward into this same pass, moving into `setup.sh`
> ahead of the clone. The repo also now installs to
> `~/code/$GITHUB_USERNAME/dotfiles` rather than `~/.dotfiles`.

> **Update ([0017](0017-omarchy-only-drop-multi-distro-support.md)):**
> "multi-distro Linux (apt + pacman)" from this ADR's original locked-in
> decisions no longer holds either - apt support was dropped entirely, and
> this repo now requires Omarchy specifically.

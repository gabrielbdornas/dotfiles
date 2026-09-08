# Architecture Decision Records

Each file here records one decision made while building the new `setup/`
process: the context that forced the decision, what was decided, and the
consequences (including what it deliberately leaves out). See the root
[README.md](../../README.md) for how to actually use the repo.

| ADR | Decision |
| --- | --- |
| [0001](0001-plain-shell-scripts-over-stow-or-chezmoi.md) | Plain shell scripts, not GNU Stow or chezmoi |
| [0002](0002-multi-distro-linux-support.md) | ~~Multi-distro Linux (apt + pacman), WSL as an independent axis~~ Superseded by 0017 |
| [0003](0003-setup-script-architecture.md) | `setup.sh` → `bootstrap.sh` → `system.sh` → `user.sh`, no numeric prefixes |
| [0004](0004-machine-profile-via-env-var.md) | Machine profile via a manually-set `DOTFILES_PROFILE` env var |
| [0005](0005-secrets-via-infisical.md) | Secrets via Infisical (hook point only, for now) |
| [0006-symlink-safety-for-externally-managed-configs.md](0006-symlink-safety-for-externally-managed-configs.md) | `link_dotfile()` backs up + warns instead of silently overwriting diverged real files |
| [0007](0007-async-login-sync-defer-shutdown-autocommit.md) | Sync on login only, async, via systemd; shutdown auto-commit deferred |
| [0008](0008-infra-only-scope-for-this-pass.md) | This pass is infrastructure only — `old_process/` content migration deferred |
| [0009](0009-require-repo-env-var-fail-fast.md) | `setup.sh` requires `REPO` via `export`, fails fast instead of a hardcoded default |
| [0010](0010-noninteractive-apt-and-distro-specific-packages.md) | ~~Non-interactive apt installs, and per-distro base package lists~~ Superseded by 0017 |
| [0011](0011-strip-repo-before-third-party-installers.md) | Strip `REPO` before invoking third-party installers (Oh My Zsh reads the same name) |
| [0012](0012-authenticate-before-cloning-into-code-dir.md) | Authenticate gh via Infisical before cloning; install into `~/code/$GITHUB_USERNAME/dotfiles` |
| [0013](0013-guard-missing-systemctl-in-user-sh.md) | ~~Guard `user.sh`'s systemd step for `systemctl` not existing at all~~ Ubuntu-specific, no longer applicable - see 0014/0015 |
| [0014](0014-confirmed-systemctl-session-bus-missing-in-containers.md) | `systemctl` can exist but have no user session bus - guard `user.sh`'s systemd step for both |
| [0015](0015-omarchy-confirms-0014-and-symlink-collision-still-untested.md) | (Proposed) Omarchy confirms 0014; the symlink collision path (0006) is still untested |
| [0016](0016-omarchy-only-not-a-desktop-dispatcher.md) | Gate Omarchy dotfiles with `is_omarchy()`, not a general desktop dispatcher |
| [0017](0017-omarchy-only-drop-multi-distro-support.md) | Drop multi-distro (apt) support entirely, require Omarchy specifically |
| [0018](0018-use-uname-n-not-hostname-for-key-naming.md) | Use `uname -n`, not `hostname`, for SSH key naming - `hostname` isn't installed on Omarchy |
| [0019](0019-omarchy-config-sync-strategy-deferred.md) | (Proposed, deferred) Omarchy config sync strategy - two plugin alternatives found, decision pending source review |

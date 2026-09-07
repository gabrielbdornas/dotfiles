# 0012 - Authenticate gh via Infisical before cloning; install into `~/code/$GITHUB_USERNAME/dotfiles`

## Status

Accepted

## Context

Comparing against [Le Wagon's actual setup flow](https://github.com/lewagon/setup/blob/master/ubuntu.md)
surfaced a real difference in ordering. Le Wagon installs everything via
copy-pasted commands (no repo needs to exist locally for that), authenticates
`gh`, learns `$GITHUB_USERNAME`, and only *then* clones the student's dotfiles
fork into `~/code/$GITHUB_USERNAME/dotfiles`. This project's `setup.sh` had
the opposite constraint: `bootstrap.sh`/`system.sh`/`user.sh` are files
*inside* the dotfiles repo, so the repo has to be cloned somewhere before any
of them can run at all - long before `gh` was installed (`system.sh`) or
authenticated (`user.sh`, near the end). That's why the repo ended up at a
fixed `~/.dotfiles` rather than a username-derived path.

Separately, testing on a fresh machine (no browser logged into GitHub - the
motivating case was literally the Docker test container) made the old
interactive `gh auth login -w` flow impractical: it needs a browser to
complete the OAuth device flow. A token-based, fully non-interactive login
was wanted instead, with the token itself pulled from Infisical rather than
typed in or committed anywhere.

## Decision

Move `gh` installation and authentication - along with everything now
required to make that non-interactive - into `setup.sh`, before the clone:

1. Install `git`, `jq`, `gh`, and the `infisical` CLI. `jq` is needed early
   now too, for parsing `gh api user`'s response before `bootstrap.sh`'s own
   package list (which already included `jq`) ever runs. Arch has no
   official non-AUR `infisical` package (`yay -S infisical-bin` needs an AUR
   helper we don't want to bootstrap); their GitHub releases publish a
   `linux_<arch>.pkg.tar.zst` asset instead, installed directly via
   `pacman -U` after resolving the download URL from their releases API.
2. Require three new variables, `export`ed like `REPO`
   ([0009](0009-require-repo-env-var-fail-fast.md)): `INFISICAL_TOKEN` (a
   machine identity token), `INFISICAL_PROJECT_ID`, and `INFISICAL_ENV`.
   `INFISICAL_ENV` is deliberately free-form (e.g. `home`/`work`), not tied
   to Infisical's own dev/staging/prod convention - it's meant to align with
   per-machine identity the same way [`DOTFILES_PROFILE`](0004-machine-profile-via-env-var.md)
   does, though as its own separate variable for now since `resolve_profile()`
   lives in `setup/lib.sh`, which doesn't exist pre-clone.
3. Fetch a secret named `GH_TOKEN` via `infisical run --token=... --projectId=... --env=... -- printenv GH_TOKEN`,
   then `gh auth login --with-token` with it - no browser involved.
4. Generate an SSH key (`ssh-keygen -t ed25519`, empty passphrase) if one
   doesn't exist, and register it with `gh ssh-key add` if not already
   registered. This needs `openssh-client` (apt) / `openssh` (pacman) -
   also not guaranteed present, so it gets the same install-if-missing
   treatment as `git`/`gh`/`jq`/`infisical`. The `GH_TOKEN` secret's PAT
   needs `admin:public_key` (classic) or "SSH keys" (fine-grained) scope for
   this to succeed - a token missing it fails here, not earlier.
   Before the first SSH connection, GitHub's host key is fetched via
   `ssh-keyscan` and appended to `known_hosts` - without this, the "can't
   establish authenticity of host" prompt would hang reading from a stdin
   that's actually the curl pipe, the same class of bug
   [0010](0010-noninteractive-apt-and-distro-specific-packages.md) fixed for
   debconf.
5. With the SSH key already registered, the dotfiles repo itself is cloned
   over SSH (`git@github.com:$REPO.git`) instead of HTTPS - the original
   HTTPS-first reasoning (a fresh machine has no SSH key yet) no longer
   applies, since the key now exists by this point in the same script.
6. `$GITHUB_USERNAME` (from `gh api user`) determines the clone target:
   `~/code/$GITHUB_USERNAME/dotfiles`, matching Le Wagon's convention. This
   makes the old standalone `mkdir -p ~/code/$GITHUB_USERNAME` in `user.sh`
   redundant - removed.
7. Because the path now varies per machine, it can no longer be hardcoded in
   `setup/systemd/dotfiles-sync.service` the way `~/.dotfiles` was. `setup.sh`
   writes it to `~/.config/dotfiles/env` (`DOTFILES_DIR=...`), and the
   systemd unit's `ExecStart` sources that file before running `sync.sh`.

`setup/system.sh` loses its only occupant (the `gh` install) and is now an
empty stub again, pending real system-level tools (VS Code, per
[0008](0008-infra-only-scope-for-this-pass.md)). `setup/user.sh` loses its
`gh auth`/`$GITHUB_USERNAME`/`mkdir` block entirely.

## Consequences

- `setup.sh` is no longer the minimal "just get git and clone" script
  [0003](0003-setup-script-architecture.md) described - it now does most of
  the security-sensitive work (auth, token handling, SSH key management)
  before anything from the repo itself has run. This is a deliberate
  reversal of that ADR's "keep setup.sh minimal" framing, forced by needing
  `$GITHUB_USERNAME` before the clone target is known.
- [0005](0005-secrets-via-infisical.md) described Infisical as "hook point
  only, for now" - this ADR is the first real use of it, superseding that
  framing for the `GH_TOKEN` secret specifically (other secrets, e.g. git
  identity, are still deferred per [0008](0008-infra-only-scope-for-this-pass.md)).
- Nothing here has been run against a real Infisical project yet - the
  `gh ssh-key add` duplicate-key detection (matching on the CLI's error text
  rather than a confirmed `gh ssh-key list` output format) and the Arch
  `.pkg.tar.zst` install path are both best-effort, flagged in code comments
  as things to confirm on the next real test run rather than points of false
  confidence.
- `docker/ubuntu-test.Dockerfile` no longer preinstalls `git` (dropped
  alongside this change, once it was noticed the test never exercised
  `setup.sh`'s own git-install branch because of it) - only
  `sudo`/`curl`/`ca-certificates` remain, the bare minimum to run the curl
  one-liner at all.

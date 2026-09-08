# 0013 - `user.sh` needs to guard for `systemctl` not existing at all

## Status

No longer directly applicable - [0017](0017-omarchy-only-drop-multi-distro-support.md)
dropped Ubuntu testing entirely, and this ADR's finding was specifically
about the Ubuntu Docker image. The still-relevant version of this problem
is [0014](0014-confirmed-systemctl-session-bus-missing-in-containers.md)/[0015](0015-omarchy-confirms-0014-and-symlink-collision-still-untested.md)
(`systemctl` existing but having no session bus, confirmed on Arch/Omarchy)
- that's the one to actually fix. Kept here as the historical record of the
first symptom found.

## Context

First real end-to-end Docker test of the full [0012](0012-authenticate-before-cloning-into-code-dir.md)
flow: `setup.sh` installed git/jq/gh/infisical, fetched `GH_TOKEN` from a
self-hosted Infisical instance (after adding `INFISICAL_DOMAIN`), ran
`gh auth login --with-token`, generated and registered an SSH key, and
cloned into `~/code/gabrielbdornas/dotfiles` - all of it worked. `bootstrap.sh`,
`system.sh`, Oh My Zsh, both zsh plugins, and both `config/hypr/*.conf`
symlinks all completed successfully too.

The run then failed on `user.sh`'s very last line:

```
/home/tester/code/gabrielbdornas/dotfiles/setup/user.sh: line 64: systemctl: command not found
```

This is a different failure mode than the one already anticipated in
[0007](0007-async-login-sync-defer-shutdown-autocommit.md) and
`docker/README.md`'s "known limitations" - those assumed `systemctl --user
enable --now` would run but fail to connect to a user session/dbus bus
inside a container. Here `systemctl` isn't installed at all - the minimal
`ubuntu:24.04` base image (and potentially other minimal environments:
other containers, some WSL configurations without systemd enabled, minimal
server installs) doesn't have `systemd` as a package. `set -e` correctly
killed the script at that exact line, meaning `user.sh` currently hard-fails
entirely in any environment without `systemctl` present, even though
everything before that line already succeeded and is worth keeping.

## Decision (for next session)

Guard the systemd install step in `setup/user.sh` with
`command -v systemctl`, and skip it with a clear warning instead of letting
`set -e` kill the whole script when it's missing:

```bash
if command -v systemctl >/dev/null 2>&1; then
  echo "===> Installing dotfiles-sync systemd unit..."
  mkdir -p "$HOME/.config/systemd/user"
  link_dotfile "$REPO_ROOT/setup/systemd/dotfiles-sync.service" "$HOME/.config/systemd/user/dotfiles-sync.service"
  systemctl --user daemon-reload
  systemctl --user enable --now dotfiles-sync.service
else
  echo "-----> systemctl not found - skipping login-sync service install (expected in containers/minimal environments)"
fi
```

Worth deciding at the same time whether this should also detect the
"systemctl exists but no user session available" case from 0007 (e.g.
`systemctl --user status >/dev/null 2>&1` before enabling) rather than just
the binary's existence, since that's the other known way this step can fail.

> **Update ([0014](0014-confirmed-systemctl-session-bus-missing-in-containers.md)):**
> confirmed for real on the Arch Docker test - `systemctl` exists there
> (unlike Ubuntu's minimal image), so this ADR's binary-only guard would
> NOT have caught it. The actual fix needs both checks combined; see 0014.

## Consequences

- Until fixed, `user.sh` (and therefore the whole `setup.sh` chain) cannot
  complete successfully in any systemd-less environment, docker test included -
  a real regression risk for anyone testing this way, not just a cosmetic log
  message.
- Everything else validated in this run stays proven: the full 0012 auth/clone
  flow, `bootstrap.sh`, Oh My Zsh, plugins, and the symlink pattern are all
  confirmed working end to end on real Ubuntu.

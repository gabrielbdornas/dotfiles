# Testing on Ubuntu via Docker

Validates the apt branch of `setup/` (`bootstrap.sh`, `system.sh`,
`user.sh`) on a fresh Ubuntu install, since day-to-day development happens
on Arch and the `pacman` branch is the one that's actually been run
end-to-end so far.

## Build

From the repo root:

```bash
docker build -t dotfiles-ubuntu-test -f docker/ubuntu-test.Dockerfile .
```

## Run

Mount the repo at `~/.dotfiles` read-only, so you're testing your local
working tree - including anything not pushed yet - not whatever's on
GitHub, and nothing the container does can modify it:

```bash
docker run --rm -it -v "$(pwd)":/home/tester/.dotfiles:ro dotfiles-ubuntu-test
```

Inside the container, run the chain starting from `bootstrap.sh` directly.
`setup.sh` itself is skipped - its only job (install git, clone the repo)
is already done by the mount:

```bash
bash ~/.dotfiles/setup/bootstrap.sh
```

That runs `bootstrap.sh` → `system.sh` → `user.sh` in order, same as a
real machine. Run it a second time afterwards to confirm the idempotency
checks actually no-op instead of reinstalling/relinking everything.

## Known limitations in this container

- **systemd user service**: `user.sh`'s last step
  (`systemctl --user enable --now dotfiles-sync.service`) will fail - a
  plain container has no systemd/dbus user session running. That's
  expected here; everything before it is what this setup is actually
  meant to validate. See [`docs/adr/0007`](../docs/adr/0007-async-login-sync-defer-shutdown-autocommit.md).
- **`gh auth login`**: opens a browser via `-w`. With no browser in the
  container, `gh` falls back to printing a one-time code and URL - open
  that URL in a browser on your host machine and enter the code to
  complete authentication for the container's session.

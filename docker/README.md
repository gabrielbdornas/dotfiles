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

Since `setup.sh` now handles gh/Infisical install, GitHub auth, and the SSH
key before the repo is even cloned (see
[`docs/adr/0012`](../docs/adr/0012-authenticate-before-cloning-into-code-dir.md)),
the real end-to-end test is the actual documented one-liner - no volume
mount needed, since `setup.sh` clones from GitHub itself. It needs four
exported variables:

```bash
docker run --rm -it dotfiles-ubuntu-test
# inside the container:
export REPO="gabrielbdornas/dotfiles" \
       INFISICAL_TOKEN="<your machine identity token>" \
       INFISICAL_PROJECT_ID="<your infisical project id>" \
       INFISICAL_ENV="home" \
  && curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/setup.sh" | bash
```

This needs a real Infisical project with a `GH_TOKEN` secret (a GitHub
personal access token with `admin:public_key`/"SSH keys" permission, so
`gh ssh-key add` can register the generated SSH key) - without that set up,
it'll fail at the "Fetching GitHub token from Infisical" step, which is
expected until that account-side setup exists.

### Quick iteration without re-authenticating every time

For iterating on `bootstrap.sh`/`system.sh`/`user.sh` specifically (not the
setup.sh/auth/clone logic), mount the repo read-only and run the chain from
`bootstrap.sh` directly - but since `user.sh` now expects
`~/.config/dotfiles/env` (normally written by `setup.sh`) to find the repo
for the systemd unit, create a stub for it first:

```bash
docker run --rm -it -v "$(pwd)":/home/tester/.dotfiles:ro dotfiles-ubuntu-test
# inside the container:
mkdir -p ~/.config/dotfiles
echo 'DOTFILES_DIR="/home/tester/.dotfiles"' > ~/.config/dotfiles/env
bash ~/.dotfiles/setup/bootstrap.sh
```

Run it a second time afterwards to confirm the idempotency checks actually
no-op instead of reinstalling/relinking everything.

## Known limitations in this container

- **systemd user service**: `user.sh`'s last step
  (`systemctl --user enable --now dotfiles-sync.service`) will fail - a
  plain container has no systemd/dbus user session running. That's
  expected here; everything before it is what this setup is actually
  meant to validate. See [`docs/adr/0007`](../docs/adr/0007-async-login-sync-defer-shutdown-autocommit.md).
- **`gh ssh-key add`**: needs the `GH_TOKEN` secret's PAT to actually carry
  SSH-key-management permission - a token missing it will fail here with a
  permission error, not earlier.

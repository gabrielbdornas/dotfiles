# Testing via Docker

`omarchy-test.Dockerfile` validates `setup/` end to end without touching a
real machine. This repo only supports Omarchy (see
[`docs/adr/0017`](../docs/adr/0017-omarchy-only-drop-multi-distro-support.md)) -
there used to be separate Ubuntu and plain-Arch images here too, dropped
along with apt/multi-distro support generally.

This image also seeds `~/.config/hypr` with Omarchy's *real* default
config, for testing `link_dotfile()`'s collision-safety path - see
[`docs/adr/0006`](../docs/adr/0006-symlink-safety-for-externally-managed-configs.md)
for why that matters. It does **not** run Omarchy's actual installer - see
the Dockerfile's own comment for why that's not practical in a container.

Only `sudo`/`curl`/`ca-certificates` are preinstalled (the bare minimum to
run the curl one-liner at all) - everything else (`git`, `gh`, `jq`,
`infisical`, `openssh`, `zsh`, ...) is installed by
`setup.sh`/`bootstrap.sh` themselves, so this test actually exercises those
install-if-missing code paths instead of silently skipping them.

## Build

From the repo root:

```bash
docker build -t dotfiles-omarchy-test -f docker/omarchy_test.Dockerfile .
```

## Run

Since `setup.sh` now handles gh/Infisical install, GitHub auth, and the SSH
key before the repo is even cloned (see
[`docs/adr/0012`](../docs/adr/0012-authenticate-before-cloning-into-code-dir.md)),
the real end-to-end test is the actual documented one-liner - no volume
mount needed, since `setup.sh` clones from GitHub itself:

```bash
docker run --rm -it dotfiles-omarchy-test
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
docker run --rm -it -v "$(pwd)":/home/tester/.dotfiles:ro dotfiles-omarchy-test
# inside the container:
mkdir -p ~/.config/dotfiles
echo 'DOTFILES_DIR="/home/tester/.dotfiles"' > ~/.config/dotfiles/env
bash ~/.dotfiles/setup/bootstrap.sh
```

Run it a second time afterwards to confirm the idempotency checks actually
no-op instead of reinstalling/relinking everything. This is also the point
where `link_dotfile()` should hit its collision path when linking
`config/hypr/keybindings.conf`/`monitors.conf` against Omarchy's
pre-existing `~/.config/hypr` content.

## Known limitations in this container

- **systemd user service**: `user.sh`'s systemd install step needs a
  working `systemctl --user` session, which this container doesn't have -
  tracked as
  [`docs/adr/0014`](../docs/adr/0014-confirmed-systemctl-session-bus-missing-in-containers.md)/[`0015`](../docs/adr/0015-omarchy-confirms-0014-and-symlink-collision-still-untested.md)
  (not yet fixed).
- **`gh ssh-key add`**: needs the `GH_TOKEN` secret's PAT to actually carry
  SSH-key-management permission - a token missing it will fail here with a
  permission error, not earlier.
- **Arch package signing**: unconfirmed so far - if `pacman -S`/`-U` fails
  with a PGP/keyring-related error, the official `archlinux` Docker image
  is expected to ship with its keyring already initialized, but this
  hasn't actually been exercised yet. If it happens,
  `pacman-key --init && pacman-key --populate archlinux` before the first
  install is the standard fix.
- **This image is an approximation**, not a real Omarchy machine - see the
  Dockerfile's own comment.

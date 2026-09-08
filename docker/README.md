# Testing via Docker

Three images validate `setup/` end to end without touching a real machine:

| Image | Dockerfile | Validates |
| --- | --- | --- |
| `dotfiles-ubuntu-test` | `ubuntu-test.Dockerfile` | apt branch (Debian/Ubuntu) |
| `dotfiles-arch-test` | `arch-test.Dockerfile` | pacman branch (Arch) |
| `dotfiles-omarchy-test` | `omarchy-test.Dockerfile` | pacman branch, plus `link_dotfile()`'s collision-safety path against Omarchy's *real* default `~/.config/hypr` layout - see [`docs/adr/0006`](../docs/adr/0006-symlink-safety-for-externally-managed-configs.md) for why that matters. It does **not** run Omarchy's actual installer - see the Dockerfile's own comment for why that's not practical in a container. |

All three follow the same principle: only `sudo`/`curl`/`ca-certificates`
preinstalled (the bare minimum to run the curl one-liner at all) -
everything else (`git`, `gh`, `jq`, `infisical`, `openssh`, `zsh`, ...) is
installed by `setup.sh`/`bootstrap.sh` themselves, so these tests actually
exercise those install-if-missing code paths instead of silently skipping
them.

## Build

From the repo root:

```bash
docker build -t dotfiles-ubuntu-test  -f docker/ubuntu-test.Dockerfile  .
docker build -t dotfiles-arch-test    -f docker/arch-test.Dockerfile    .
docker build -t dotfiles-omarchy-test -f docker/omarchy-test.Dockerfile .
```

## Run

Since `setup.sh` now handles gh/Infisical install, GitHub auth, and the SSH
key before the repo is even cloned (see
[`docs/adr/0012`](../docs/adr/0012-authenticate-before-cloning-into-code-dir.md)),
the real end-to-end test is the actual documented one-liner - no volume
mount needed, since `setup.sh` clones from GitHub itself. Same command for
all three images, just swap the image name:

```bash
docker run --rm -it dotfiles-ubuntu-test   # or dotfiles-arch-test / dotfiles-omarchy-test
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
for the systemd unit, create a stub for it first. Same pattern for all
three images:

```bash
docker run --rm -it -v "$(pwd)":/home/tester/.dotfiles:ro dotfiles-ubuntu-test   # or arch/omarchy
# inside the container:
mkdir -p ~/.config/dotfiles
echo 'DOTFILES_DIR="/home/tester/.dotfiles"' > ~/.config/dotfiles/env
bash ~/.dotfiles/setup/bootstrap.sh
```

Run it a second time afterwards to confirm the idempotency checks actually
no-op instead of reinstalling/relinking everything. On the Omarchy image,
this is also the point where `link_dotfile()` should hit its collision
path when linking `config/hypr/keybindings.conf`/`monitors.conf` against
Omarchy's pre-existing `~/.config/hypr` content.

## Known limitations in these containers

- **systemd user service**: `user.sh`'s systemd install step needs
  `systemctl` to exist at all, which a plain container doesn't have -
  confirmed failing on the Ubuntu image, tracked as
  [`docs/adr/0013`](../docs/adr/0013-guard-missing-systemctl-in-user-sh.md)
  (not yet fixed). Expected on all three images until that's guarded.
- **`gh ssh-key add`**: needs the `GH_TOKEN` secret's PAT to actually carry
  SSH-key-management permission - a token missing it will fail here with a
  permission error, not earlier.
- **Arch package signing**: unconfirmed so far - if `pacman -S`/`-U` fails
  with a PGP/keyring-related error on the Arch or Omarchy image, the
  official `archlinux` Docker image is expected to ship with its keyring
  already initialized, but this hasn't actually been exercised yet. If it
  happens, `pacman-key --init && pacman-key --populate archlinux` before
  the first install is the standard fix.
- **Omarchy image is an approximation**, not a real Omarchy machine - see
  the Dockerfile's own comment and the table above.

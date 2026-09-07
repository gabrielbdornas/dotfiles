# dotfiles

Personal dotfiles and machine setup for multiple Linux machines (home,
work), bootstrapped with a single command and kept in sync afterwards.

`old_process/` is the previous approach (forked from Le Wagon's bootcamp
dotfiles) — kept as a reference, not deleted, not replicated exactly.
`setup/` is the current process and the one described below. Decision
rationale for *why* things are built this way lives in
[`docs/adr/`](docs/adr/README.md), not here — this file is just how to use
the repo.

## Setup a new machine

```bash
REPO="gabrielbdornas/dotfiles"
curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/setup.sh" | bash
```

Supports Debian/Ubuntu and Arch (including under WSL). On first run you'll
be asked which profile this machine is (see below) and, if not already
authenticated, to log in to GitHub CLI.

## Update an already-set-up machine

Runs automatically once per login in the background (see
`setup/systemd/dotfiles-sync.service`) — you'll get a desktop notification
when it finishes or fails. To run it by hand instead:

```bash
bash ~/.dotfiles/setup/sync.sh
```

## Machine profile

Home/work differences are controlled by `DOTFILES_PROFILE`. Set it once
per machine, e.g. in a shell rc file that's *not* checked into this repo:

```bash
export DOTFILES_PROFILE=work
```

If it's not set, `setup/user.sh` asks once (interactively) and remembers
the answer in `~/.config/dotfiles/profile`.

## Pushing your own changes back

Not automated yet — edit, then from `~/.dotfiles`:

```bash
git add -A
git commit -m "..."
git push
```

## Layout

```
setup.sh                entrypoint — curl this
setup/bootstrap.sh       base packages, sudo, locale
setup/system.sh          system-level tools (GitHub CLI)
setup/user.sh            shell, plugins, dotfile symlinks, gh auth, workspace
setup/lib.sh             shared helpers (distro/WSL detection, symlink helper, ...)
setup/sync.sh            pull + re-apply, run by the systemd unit
config/hypr/             example dotfiles proving the symlink pattern
docs/adr/                why things are built this way
old_process/             previous approach, kept as reference
```

Each script hands off to the next: `setup.sh` → `bootstrap.sh` →
`system.sh` → `user.sh`. See [`docs/adr/0003`](docs/adr/0003-setup-script-architecture.md)
for why, and the rest of `docs/adr/` for every other decision baked into
this layout (multi-distro support, the profile mechanism, secrets via
Infisical, the symlink safety behavior, sync timing, and what's
deliberately not migrated yet).

## Q&A

Practical questions about how the code works, answered here so nothing
gets lost.

**Q: What does `set -euo pipefail` at the top of every script actually do?**

It's three shell options bundled together:

- **`-e`** (errexit): the script exits immediately if any command fails,
  instead of continuing as if nothing happened. Without it, a failed
  `sudo pacman -S ...` would just print an error and the script would keep
  going.
- **`-u`** (nounset): referencing an unset variable is an error instead of
  silently expanding to an empty string. If `SCRIPT_DIR` were ever unset
  due to a typo, `-u` catches it immediately rather than letting something
  like `rm -rf "$SCRIPT_DIR/..."` quietly run against an empty path.
- **`pipefail`**: a pipeline's exit status is normally just its *last*
  command's, so `false | true` "succeeds." With `pipefail`, the whole
  pipeline fails if *any* stage does — which matters in `setup/system.sh`'s
  `curl ... | sudo dd of=...` for the GitHub CLI key: without it, a failed
  `curl` would be masked by `dd` succeeding on empty input, leaving a
  broken key in place with no error raised.

Net effect: these scripts fail loudly and immediately rather than limping
forward into a half-configured machine. One caveat: `-e` does **not**
trigger inside an `if condition; then ...`, an `&&`/`||` chain, or a
function called from one of those — which is why the scripts still use
explicit `if ! command; then ...` checks throughout instead of relying on
`-e` alone.

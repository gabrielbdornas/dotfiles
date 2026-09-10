# dotfiles

Personal dotfiles and machine setup for Omarchy machines, bootstrapped
with a single command and kept in sync afterwards.

`old_process/` is the previous approach (forked from Le Wagon's bootcamp
dotfiles) — kept as a reference, not deleted, not replicated exactly.
`setup/` is the current process and the one described below. Decision
rationale for *why* things are built this way lives in
[`docs/adr/`](docs/adr/README.md), not here — this file is just how to use
the repo.

`ress/` is a work-in-progress backup/restore/sync layer built on the code of
[btsouth/omarchy-resurrect](https://github.com/btsouth/omarchy-resurrect)
("ress"), copied in (MIT-licensed) rather than tracked as a fork, with new
capabilities layered on top — see `ress/README.md` and `docs/adr/` for the
decision and its current status.

## Setup a new machine

```bash
export REPO="gabrielbdornas/dotfiles" \
       INFISICAL_TOKEN="<machine identity token>" \
       INFISICAL_PROJECT_ID="<infisical project id>" \
       INFISICAL_ENV="home" \
  && curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/setup.sh" | bash
```

All four must be `export`ed, not just set — see the Q&A below for why. If
your Infisical is self-hosted (not `app.infisical.com`), also export
`INFISICAL_DOMAIN="https://your-instance.com"` (bare origin, no `/api`
suffix) — the `infisical` CLI reads this env var itself, no script change
needed.

Requires Omarchy specifically — `setup.sh` checks `/etc/os-release` for
`ID=omarchy` and fails fast otherwise, even on plain (non-Omarchy) Arch
(see [`docs/adr/0017`](docs/adr/0017-omarchy-only-drop-multi-distro-support.md)).
`setup.sh` installs `gh` and the `infisical` CLI, pulls a GitHub token out
of Infisical (secret name `GH_TOKEN`, from the project/environment above),
authenticates `gh` with it, generates and registers an SSH key, then
clones this repo into `~/code/<your-github-username>/dotfiles` — that
requires the `GH_TOKEN` secret's PAT to carry SSH-key-management
permission (`admin:public_key`/"SSH keys"). Everything after the clone
(shell, plugins, dotfile symlinks, the sync service) proceeds
automatically.

## Update an already-set-up machine

Runs automatically once per login in the background (see
`setup/systemd/dotfiles-sync.service`) — you'll get a desktop notification
when it finishes or fails. To run it by hand instead, source the location
`setup.sh` recorded for you (the repo lives at
`~/code/<your-github-username>/dotfiles`, not a fixed path — see the Q&A):

```bash
source ~/.config/dotfiles/env && bash "$DOTFILES_DIR/setup/sync.sh"
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

Not automated yet — edit, then from `~/code/<your-github-username>/dotfiles`:

```bash
git add -A
git commit -m "..."
git push
```

## Testing without a real Omarchy machine

A Docker image approximates Omarchy for testing `setup/` end to end,
including the dotfile-symlink collision-safety path against Omarchy's real
config layout. See [`docker/README.md`](docker/README.md) for how to build
and run it.

## Layout

```
setup.sh                entrypoint — curl this. git/gh/jq/infisical install,
                         GitHub auth via Infisical token, SSH key, clone
setup/bootstrap.sh       base packages, sudo, locale
setup/system.sh          system-level tools (currently empty - gh moved to setup.sh)
setup/user.sh            shell, plugins, dotfile symlinks, sync service install
setup/lib.sh             shared helpers (Omarchy check, symlink helper, ...)
setup/sync.sh            pull + re-apply, run by the systemd unit
config/hypr/             example dotfiles proving the symlink pattern
docs/adr/                why things are built this way
docker/                  Omarchy-approximation container for testing setup/
old_process/             previous approach, kept as reference
```

Each script hands off to the next: `setup.sh` → `bootstrap.sh` →
`system.sh` → `user.sh`. See [`docs/adr/0003`](docs/adr/0003-setup-script-architecture.md)
for the original shape and [`docs/adr/0012`](docs/adr/0012-authenticate-before-cloning-into-code-dir.md)
for why `setup.sh` ended up taking on so much more than "just clone the
repo," and the rest of `docs/adr/` for every other decision baked into this
layout (why Omarchy-only per [`docs/adr/0017`](docs/adr/0017-omarchy-only-drop-multi-distro-support.md),
the profile mechanism, the symlink safety behavior, sync timing, and what's
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
  pipeline fails if *any* stage does — which matters in `setup.sh`'s
  `curl ... | grep ... | sed ...` for resolving the Infisical CLI's
  download URL: without it, a failed `curl` would be masked by `grep`/`sed`
  succeeding trivially on empty input, potentially leaving `INFISICAL_PKG_URL`
  silently empty instead of the script stopping right there.

Net effect: these scripts fail loudly and immediately rather than limping
forward into a half-configured machine. One caveat: `-e` does **not**
trigger inside an `if condition; then ...`, an `&&`/`||` chain, or a
function called from one of those — which is why the scripts still use
explicit `if ! command; then ...` checks throughout instead of relying on
`-e` alone.

**Q: Why does `REPO` need `export`, not just `REPO=...`?**

`curl -fsSL <url> | bash` streams the downloaded script straight into a
*new* `bash` process's stdin — it's never saved to disk first. A plain
`REPO="x"` set in your shell before that command stays local to your
shell; it does **not** carry over into that new process. Only an
`export`ed variable is inherited by child processes. `setup.sh` has no
hardcoded fallback (see [`docs/adr/0009`](docs/adr/0009-require-repo-env-var-fail-fast.md)),
so without `export` it fails immediately with a clear error instead of
silently doing the wrong thing.

Note you still type the repo name twice either way: once in the `curl`
URL itself (that's how `curl` finds the file to fetch), and once in
`export REPO=...` (so `setup.sh` knows what to `git clone`). There's no
way for the script to recover the URL it was fetched from and skip the
second one.

The same reasoning applies to `INFISICAL_TOKEN`, `INFISICAL_PROJECT_ID`,
and `INFISICAL_ENV` — all three are read inside `setup.sh` itself, so all
three need `export`, not just `=`, for the same stdin-is-the-pipe reason.

**Q: Why does the repo end up at `~/code/<username>/dotfiles` instead of `~/.dotfiles`?**

Originally it was a fixed `~/.dotfiles`. But once `gh` auth moved into
`setup.sh` (to fetch a token from Infisical before doing anything else -
see [`docs/adr/0012`](docs/adr/0012-authenticate-before-cloning-into-code-dir.md)),
`$GITHUB_USERNAME` becomes knowable *before* the clone, matching
[Le Wagon's own convention](https://github.com/lewagon/setup/blob/master/ubuntu.md)
of putting every repo — dotfiles included — under `~/code/<username>/`.
Since the path now varies per machine, it can't be hardcoded in
`setup/systemd/dotfiles-sync.service` the way `~/.dotfiles` was; `setup.sh`
records it in `~/.config/dotfiles/env` instead, which both the systemd unit
and the "update by hand" command above read from.

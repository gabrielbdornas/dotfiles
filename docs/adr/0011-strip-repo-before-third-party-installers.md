# 0011 - Strip `REPO` before invoking third-party installers

## Status

Accepted

## Context

The Ubuntu Docker test hit a confusing failure: `setup/user.sh`'s Oh My
Zsh install step failed with
`sed: can't read /home/tester/.oh-my-zsh/templates/zshrc.zsh-template: No such file or directory`.

The actual clone that ran wasn't Oh My Zsh at all — the log showed a small
shallow clone, then `From https://github.com/gabrielbdornas/dotfiles`,
`* [new branch] main -> origin/main`, `* [new branch] master ->
origin/master`, and `Already on 'master'`. Oh My Zsh's own installer reads
an environment variable named `REPO` (undocumented in its help text, but a
known way to install from a fork: `REPO=${REPO:-ohmyzsh/ohmyzsh}`,
`REMOTE=https://github.com/${REPO}.git`, `BRANCH=${BRANCH:-master}`) - the
exact same variable name this repo uses for its own, unrelated purpose
(see [0009](0009-require-repo-env-var-fail-fast.md)).

Because `setup.sh` does `export REPO=...`, that export is inherited by
*every* descendant process for the rest of the run - not just our own
scripts, but any third-party script invoked anywhere downstream, including
`sh -c "$(curl ... ohmyzsh/install.sh)"` deep inside `user.sh`. Oh My Zsh's
installer picked up `REPO=gabrielbdornas/dotfiles` and cloned this
dotfiles repo into `~/.oh-my-zsh` instead of the real Oh My Zsh source -
which obviously has no `templates/zshrc.zsh-template`, hence the `sed`
failure. `BRANCH`'s own hardcoded default (`master`) is unrelated to us,
which is why `git checkout master` against our repo succeeded quietly
(this repo still has a stale `master` branch) rather than erroring
somewhere more obviously.

This is the direct flip side of [0009](0009-require-repo-env-var-fail-fast.md):
the same `export` that correctly carries `REPO` into our own `setup.sh`
also carries it into anything else downstream that happens to read a
same-named variable, which we don't control and can't rename.

## Decision

Strip `REPO` specifically for the one command that shouldn't see it:

```bash
env -u REPO RUNZSH=no CHSH=no sh -c "$(curl -fsSL <ohmyzsh install url>)"
```

`env -u NAME` removes a variable from the environment of the command it
runs, combinable with `NAME=value` settings on the same line (verified:
`RUNZSH`/`CHSH` still get set correctly while `REPO` comes back unset
inside the invoked command).

## Consequences

- Any other third-party installer invoked later in `setup/` needs the same
  scrutiny: check whether it reads any of this repo's own env var names
  (`REPO`, `DOTFILES_PROFILE`) before assuming `export`ing them globally in
  `setup.sh` is harmless everywhere downstream.
- This was only caught by the Ubuntu Docker test - the local Arch machine
  never exercises the full `user.sh` chain in one uninterrupted run the
  same way, and the failure mode (a plausible-looking but wrong clone)
  doesn't announce itself as an env var collision at all; it just looks
  like a broken Oh My Zsh install.

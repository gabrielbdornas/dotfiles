# 0006 - `link_dotfile()` backs up + warns instead of silently overwriting diverged real files

## Status

Accepted

## Context

`main_idea.md` raised a concrete risk: the Omarchy Claude Code skill
already manages files under `~/.config/hypr/...`. If this repo's setup also
symlinks into the same paths, what happens when both touch the same file?

The basic backup-then-symlink pattern from `old_process/install.sh` (and
from the earlier design conversation in
`dotfiles_setup_conversation_summary.md`) only checks *whether* a target
exists as a real file, not whether its content is something worth keeping.
Concretely: many tools, including the Omarchy skill and plenty of editors,
write files atomically — write to a temp file, then rename over the
target. That rename *replaces* a symlink with a real file, silently
detaching it from the repo. A naive backup-then-relink on every run would
happily discard that real file's content the moment `link_dotfile` next
runs (e.g. via the login sync in
[0007](0007-async-login-sync-defer-shutdown-autocommit.md)), even if it
held a legitimate recent edit.

## Decision

`setup/lib.sh:link_dotfile(src, dest)` handles three cases:

1. `dest` doesn't exist → create the symlink.
2. `dest` is already the correct symlink → no-op.
3. `dest` is a real file → back it up to `dest.backup`, then symlink —
   but if that real file's content **differs** from `src`, print an
   explicit warning before doing so, rather than treating this the same as
   an identical-content backup.

The repo version still wins in both file sub-cases (this pass does not
attempt automatic reconciliation), but the diverged content is never
silently lost — it's always in `dest.backup`, and the warning is the
signal to go check it before assuming the repo is what you actually want.

## Consequences

- Safe to re-run `link_dotfile` (and therefore the whole `bootstrap.sh`
  chain) unattended, from the login-sync service, without risking a silent
  data loss on a file something else just wrote to.
- `config/hypr/keybindings.conf` and `config/hypr/monitors.conf` were
  chosen as the first real dotfiles run through this path specifically
  because they're the same files the Omarchy skill touches — they're the
  real-world test case for this exact scenario, not arbitrary examples.
- Reconciling a genuine conflict (repo says one thing, the diverged real
  file said another) is still a manual step: read `dest.backup`, decide,
  edit the repo file if needed, re-run. Automating that is future work,
  not attempted here.

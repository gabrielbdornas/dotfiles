# 0004 - Machine profile via a manually-set `DOTFILES_PROFILE` env var

## Status

Accepted

## Context

Home and work machines need to differ in small ways (git identity, a
handful of paths), but `old_process/` handled this by literally pasting
both machines' values into the same file (`zprofile`, `zshrc`) — there was
no concept of "which machine is this" anywhere in the code. Three ways to
represent that concept were considered: an explicit profile file per
machine, auto-detection from hostname/username, or a manually-set
environment variable.

Hostname/username auto-detection was ruled out as brittle — it silently
breaks if a hostname changes, and ties behavior to a value that has nothing
inherently to do with "home" vs. "work."

## Decision

A manually-set `DOTFILES_PROFILE` environment variable, resolved by
`setup/lib.sh:resolve_profile()` in this order: the env var if set,
otherwise a persisted value at `~/.config/dotfiles/profile`, otherwise
(only when running interactively) a one-time prompt whose answer gets
persisted to that file.

The persistence step exists specifically because `setup/sync.sh` runs
non-interactively, from a systemd unit with no attached terminal (see
[0007](0007-async-login-sync-defer-shutdown-autocommit.md)) — it can't
prompt, so the very first (interactive) run has to have already recorded
the answer.

## Consequences

- Setting up a new machine requires one manual step (answering the prompt,
  or exporting `DOTFILES_PROFILE` up front) — this is intentional, not an
  oversight.
- No script in this pass actually branches on the profile's value yet;
  this ADR only fixes *how* the value is obtained and persisted. Real
  per-profile differences (e.g. git identity) get wired up when that
  content is migrated — see
  [0008](0008-infra-only-scope-for-this-pass.md).

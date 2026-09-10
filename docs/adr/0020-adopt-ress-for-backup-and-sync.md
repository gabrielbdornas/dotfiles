# 0020 - Adopt `ress`'s code for backup/restore/sync, on a branch, not a fork

## Status

Accepted. Live-symlink mode implemented and tested on
`feat/ress-backup-sync`; the Infisical/gh/SSH bootstrap port described below
is not yet done.

## Context

[0019](0019-omarchy-config-sync-strategy-deferred.md) left "how do we sync
Omarchy config across machines" deliberately open, pending source review of
two candidate plugins. That review happened, and while researching it a
third project surfaced -
[btsouth/omarchy-resurrect](https://github.com/btsouth/omarchy-resurrect)
("ress") - that turned out to answer a bigger question than the one 0019 was
asking: not "sync some dotfiles" but "everything installed on one machine
reproduces onto a fresh one." It captures packages (`pacman -Qqen`/`-Qqem`),
a curated dotfile list, Omarchy's own config (shell layout, themes, hooks),
web apps, shell plugins pinned to an exact commit, and opt-in `age`-encrypted
secrets - into a git-backed vault, replayed with a resumable restore. Its
CLI (`bin/ress`, ~3275 lines) has no QML dependency and real adversarial-input
hardening: a documented CVE-class fix (an unvalidated `schemaVersion` reaching
bash arithmetic, exploitable via command substitution) and an explicit
hostile-vault/hostile-loadout test suite.

Our own `setup/lib.sh`/`bootstrap.sh`/`system.sh`/`user.sh` chain already did
a narrower version of this, worse: no package-manifest tracking, no
plugin-pinning, no encrypted secrets, no resumable restore, no adversarial
hardening, no test suite. Continuing to grow that chain to match what `ress`
already does would be more total work than adopting `ress`'s code and adding
the pieces it doesn't have.

Three gaps identified against our own design, all confirmed in discussion:

1. `ress` has no equivalent of `setup.sh`'s Infisical-backed GitHub auth
   bootstrap (fetch `GH_TOKEN` from Infisical, `gh auth login --with-token
   --git-protocol ssh`, generate + register an SSH key) - needed to get a
   fresh Omarchy machine from nothing to a working `git`/`gh` before any
   vault can be cloned at all.
2. `ress`'s own secrets category is `age`-based and vault-local; Infisical's
   role here is narrower and different - a one-time, persistent machine
   login (like `gh`'s SSH auth) that other tooling can reuse afterward, not
   a replacement for `ress`'s existing secrets mechanism. The two coexist
   untouched.
3. `ress` is snapshot/restore only: `ress backup` copies a point-in-time
   state into the vault; nothing keeps the vault current between runs. That
   is fine for most of what it captures, but wrong for something like
   `~/.claude` that should just always be current across machines with no
   explicit "did I remember to back up" step.

## Decision

Adopt `ress`'s code as the base for a personal backup/restore/sync tool,
copied wholesale into this repo rather than tracked as a GitHub fork - the
user's explicit preference, since `ress`'s own documented dev workflow
(`rsync` the working tree into the plugin directory) doesn't require
`omarchy plugin add`/a separate repo to develop or test against, either on a
real Omarchy machine or `docker/omarchy_test.Dockerfile`'s approximation. A
dedicated repo is a decision for later, only if this graduates to something
installed via `omarchy plugin add <url>` for real.

Landed on `feat/ress-backup-sync` (commit `85d533f`):

- `btsouth/omarchy-resurrect`'s source (MIT-licensed, license retained)
  copied into `ress/`, with `manifest.json`'s plugin `id` changed from
  `tsouth89.resurrect` to `gabrielbdornas.ress` - a deliberate divergence
  from upstream's own convention of never renaming their id, because this
  copy *is* meant to diverge in behavior and needs its own identity if it's
  ever installed as a real plugin.
- A new opt-in **live-symlink capture/restore mode**: paths listed in
  `~/.config/ress/symlink` (same format as the existing `include` list,
  loaded through the same `merged_list` helper) are moved into the vault and
  replaced with a symlink on `ress backup`, instead of rsync-copied - so an
  edit on either side is immediately visible on the other, no second
  `ress backup` required. `ress restore` recreates the same link on a fresh
  machine. The divergence-safety behavior is ported near-verbatim from this
  repo's own `setup/lib.sh:link_dotfile()`: a real file reappearing with
  different content is backed up (to `<entry>.ress-bak`, `ress`'s own
  existing backup-suffix convention), never silently discarded. Covered by
  `ress/tests/cases/17-symlink-mode.sh`, following the existing sandboxed
  test-harness pattern; full pre-existing suite (17 cases, 477 assertions)
  still passes.

Not yet done, deliberately sequenced second (see "Suggested sequencing" in
the working plan this ADR documents): a new `cmd_bootstrap` subcommand
porting `setup.sh`'s Infisical/gh/SSH auth logic near-verbatim, gated by new
config keys (`INFISICAL_ENABLED`, `INFISICAL_PROJECT_ID`, `INFISICAL_ENV`,
`INFISICAL_DOMAIN` - `INFISICAL_TOKEN` itself stays environment-only, never
persisted, same posture as [0009](0009-require-repo-env-var-fail-fast.md)),
plus a new `packages` list (same `merged_list` mechanism) replacing
`setup/bootstrap.sh`'s hardcoded `BASE_PACKAGES` array, and three new
`ress doctor` checks (Infisical CLI present, Infisical authenticated, `gh`
authenticated over SSH). This was deferred until the live-symlink mode -
genuinely new code - proved out, since the bootstrap port is a higher
blast-radius change: it replaces code in `setup.sh` that already works and
is tested today.

## Consequences

- `docs/adr/0019` is superseded by this decision - the config-sync question
  it left open is answered by adopting `ress` instead of either of the two
  plugins it was comparing.
- This also revises the scope of two other ADRs, though neither is retired
  outright yet since `setup.sh` still exists and works on `main`:
  - [0007](0007-async-login-sync-defer-shutdown-autocommit.md) (async
    login-sync via a systemd unit) will be superseded once `ress`'s own
    `Service.qml`/`AUTO_BACKUP` timer takes over that job.
  - [0009](0009-require-repo-env-var-fail-fast.md) and
    [0012](0012-authenticate-before-cloning-into-code-dir.md) (the
    `REPO`/`INFISICAL_*` env var contract and the auth-before-clone
    ordering) will move from `setup.sh` into the new `cmd_bootstrap`'s own
    config/doctor surface once that port lands - the underlying reasoning in
    both ADRs carries over unchanged, only its home moves.
- Until the bootstrap port lands, `setup.sh` and `feat/ress-backup-sync`
  are two independent, un-integrated paths - `main` is unaffected by any of
  this. No machine should be pointed at `ress bootstrap` yet; it does not
  exist.
- `ress/` now carries a second test suite and a second, larger surface
  (~3275-line CLI plus QML) that this repo is responsible for keeping
  working, on top of everything `setup/` already covered - a real ongoing
  maintenance cost accepted in exchange for not re-deriving package-manifest
  tracking, plugin-pinning, encrypted secrets, resumable restore, and
  adversarial-input hardening from scratch.

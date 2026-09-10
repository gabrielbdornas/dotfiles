# 0019 - Omarchy config sync strategy: deferred, two plugin alternatives to evaluate

## Status

Superseded by [0020](0020-adopt-ress-for-backup-and-sync.md) - a third
project (`ress`) answered a bigger version of this question than either
plugin below, and was adopted instead. Kept here as the historical record of
the two plugins considered first and why neither was picked.

## Context

[0015](0015-omarchy-confirms-0014-and-symlink-collision-still-untested.md)
flagged that `link_dotfile()`'s backup-and-warn collision path
([0006](0006-symlink-safety-for-externally-managed-configs.md)) has never
actually been exercised by any Docker test. While discussing how to test
that collision path, a bigger, unresolved question came up: what should
this repo's actual strategy be for syncing Omarchy's `~/.config`-based
configuration (hypr, theme, shell layout, etc.) across machines over time -
not just the two example files (`config/hypr/keybindings.conf`,
`config/hypr/monitors.conf`) it links today?

### Why "copy the whole tree in and symlink everything" doesn't work

Omarchy ships its own update/migration tooling that patches user config
files in place over time. If `link_dotfile()` claims a file, a later
Omarchy migration writing to that path either gets silently overridden by
the (now stale) repo copy, or trips `link_dotfile()`'s diverged-content
collision/backup warning on every single Omarchy update that touches it.
A full-tree copy-and-symlink approach fights Omarchy's own maintenance
model instead of working with it - this reinforces 0006's existing
selective-ownership design rather than replacing it: claim only files
deliberately wanted versioned/identical across machines, leave everything
else to Omarchy.

### Two existing third-party plugins solve a version of this already

1. **[gladimdim/omarchy-config-sync-plugin](https://github.com/gladimdim/omarchy-config-sync-plugin)**
   - Bidirectional (push/pull) sync of `~/.config/hypr/`,
     `~/.config/omarchy/` (`shell.json`, themes, branding, plugins, hooks,
     agents), `~/.local/bin/` scripts, and matching terminal configs (e.g.
     `alacritty.toml`), against a private git repo.
   - Real drift detection on open and every 10 minutes: local-only edits,
     incoming remote files, both-changed files, and actual git merge
     conflicts - with a per-file cherry-pick "keep local / take repo"
     resolution UI, and timestamped whole-directory backups
     (`~/.config/omarchy-backup.<timestamp>/`) before applying.
   - Explicitly excludes `hypr/monitors.lua` from sync by default (opt-in
     only via "Include display layout"), because display layout is
     machine-specific. This independently validates that this repo's own
     `config/hypr/monitors.conf` is a poor example file to have chosen -
     see Decision below.
   - Installed via `omarchy plugin add <url>` + `omarchy plugin enable`
     (both scriptable), but linking it to an actual config repo is
     **GUI-only**: paste the git URL into a tray icon, click "Apply". No
     documented env var, config file, or CLI path for the repo URL or
     credentials, so it doesn't fit this repo's non-interactive
     curl-pipe-bash model
     ([0009](0009-require-repo-env-var-fail-fast.md),
     [0010](0010-noninteractive-apt-and-distro-specific-packages.md),
     [0012](0012-authenticate-before-cloning-into-code-dir.md)) without a
     manual per-machine step - unless the plugin's actual state file
     (likely under `~/.local/share/omarchy-config-sync/`) can be
     pre-written by `setup.sh` to fake that link step. **Not yet
     confirmed** - only the README was read via `WebFetch`, not the
     source.

2. **[harel/omarchy-synchro](https://github.com/harel/omarchy-synchro)**
   - A different design: explicit allowlist (`policy/allowlist.tsv`
     stored in a user-selected repo) rather than symlinks, syncing app
     configs, terminal settings, Hyprland/MIME config, package lists,
     shell layout/widgets, and third-party plugin declarations.
   - Mandatory exclusions for secrets/credentials/browser profiles/
     keyrings/caches, and read-only protection for system directories.
   - Also installed via `omarchy plugin add <url>`; setup proceeds through
     a native dashboard GUI with "optional CLI commands" - **not yet
     confirmed** how much of the flow those CLI commands actually cover,
     or whether they're sufficient for a fully non-interactive `setup.sh`
     run.
   - Keeps plugin code and the personal config repo separate, and
     separates snapshot/commit/push as independent steps (rather than a
     single push/pull like the plugin above).

Neither plugin's actual source has been read yet - both summaries above
come from README-level `WebFetch` descriptions, not the implementation.

## Decision

**None made yet - explicitly deferred.** This ADR is a checkpoint
preserving the discussion and findings so far, not a commitment to a
direction.

What *is* settled regardless of which sync strategy is eventually chosen:
`config/hypr/monitors.conf` should not be treated as a meaningful example
of "the kind of file worth syncing across machines" - both plugins
independently exclude monitor layout by default, since display layout is
inherently per-machine. Any future selection of real files to sync should
follow that same instinct.

Next concrete step for a future session: read the actual source of both
plugins (not just their READMEs) to answer definitively whether either
supports non-interactive provisioning (an env var, a config file, or a
state file `setup.sh` could pre-seed to skip the GUI linking step), then
decide between:

- (a) adopt one of the two plugins for the broader
  Omarchy-environment-sync problem, and keep `link_dotfile()` scoped to
  the small, selective set of files it already handles, or
- (b) build sync directly into this repo, or
- (c) some hybrid of the two.

## Consequences

- [0015](0015-omarchy-confirms-0014-and-symlink-collision-still-untested.md)'s
  original ask (exercise the collision path in the Docker test) is
  unblocked by this and independent of which broader strategy is
  eventually chosen - it tests an already-shipped mechanism, not a future
  one. Can be picked up on its own anytime.
- Until a strategy is chosen, this repo's Omarchy-specific dotfiles
  surface should stay exactly as small as it is today - no new files
  should be added under `config/hypr/` on the assumption "we'll figure out
  the general sync story later," since that assumption is exactly what's
  unresolved here.
- Whichever plugin (if either) is chosen determines whether `setup.sh`
  needs a new step at all, or whether config sync ends up explicitly out
  of scope for `setup.sh`/this repo and configured once manually per
  machine instead.

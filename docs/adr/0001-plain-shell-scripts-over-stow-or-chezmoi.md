# 0001 - Plain shell scripts, not GNU Stow or chezmoi

## Status

Accepted

## Context

`old_process/install.sh` symlinked a handful of dotfiles with a hand-rolled
backup+symlink loop. Two purpose-built alternatives were considered for the
rewrite:

- **GNU Stow** — a symlink-farm manager. No templating; per-machine
  differences would have to be written as shell conditionals inside the
  dotfiles themselves.
- **chezmoi** — templated dotfiles rendered per-machine from variables
  (hostname, OS, custom data), with built-in support for pulling secrets
  from a secret manager at apply-time.

chezmoi's templating looked like a good fit at first glance for the
home/work profile problem, and its secret-manager integrations lined up
with the intent to use Infisical. But it's also a new tool with its own
templating language (Go templates) to learn, and a bigger conceptual jump
from the existing shell-script mental model.

## Decision

Keep plain `.sh` scripts, in the same spirit as `old_process/install.sh`
but de-duplicated and made properly idempotent (see
[0006](0006-symlink-safety-for-externally-managed-configs.md) for the
symlink helper itself). No Stow, no chezmoi.

## Consequences

- No new dependency and no new templating language — anyone who can read
  the existing shell scripts can read the new ones.
- Per-machine differences (see
  [0004](0004-machine-profile-via-env-var.md)) have to be written as
  explicit shell conditionals inside scripts/dotfiles, reading
  `DOTFILES_PROFILE`, rather than being handled by a templating engine.
  Given home/work configs are "almost identical," this was judged to be a
  small, manageable amount of branching rather than a reason to adopt
  chezmoi.
- Secrets integration (Infisical) has to be wired up by hand — shelling out
  to the `infisical` CLI from scripts — instead of using a built-in
  template function. See [0005](0005-secrets-via-infisical.md).

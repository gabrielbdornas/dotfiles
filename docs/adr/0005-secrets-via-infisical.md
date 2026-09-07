# 0005 - Secrets via Infisical (hook point only, for now)

## Status

Accepted

## Context

`old_process/gitconfig` hardcodes a personal git identity and a
work-machine-specific CI runner path directly in a file that's symlinked
(and therefore committed to a public-facing repo layout) into `$HOME`.
Once real per-machine content gets migrated into the new process, those
kinds of values need to stop living in plaintext in the repo.

## Decision

Secrets will be sourced from Infisical. This pass does not migrate any
actual secret-backed content (see
[0008](0008-infra-only-scope-for-this-pass.md)), so there is no Infisical
CLI call anywhere in `setup/` yet — this ADR records the choice so the
hook point is built consistently once it's needed, rather than each future
script picking its own approach.

Because the shell-scripts decision in
[0001](0001-plain-shell-scripts-over-stow-or-chezmoi.md) ruled out
chezmoi, there's no built-in template function to pull a secret at
render-time. The intended shape once this is wired up: scripts shell out
to the `infisical` CLI (e.g. `infisical run -- <cmd>`, or reading a value
directly) at the point a real value is needed, gated by
`DOTFILES_PROFILE` to select which Infisical project/environment to read
from.

## Consequences

- No secret ever needs to be committed to this repo, once content
  migration reaches the files that currently hardcode identity/paths.
- Every machine needs the `infisical` CLI installed and authenticated
  before secret-dependent scripts can run — this becomes a new
  `bootstrap.sh` or `system.sh` responsibility when that work starts.
- Until then, anything that would need a secret is simply not migrated
  yet.

> **Update ([0012](0012-authenticate-before-cloning-into-code-dir.md)):**
> the `GH_TOKEN` secret (a GitHub PAT, used for non-interactive `gh` auth)
> is now a real, working use of Infisical - installed and authenticated in
> `setup.sh` itself, via `INFISICAL_TOKEN`/`INFISICAL_PROJECT_ID`/
> `INFISICAL_ENV` rather than `DOTFILES_PROFILE`. This "hook point only"
> framing no longer applies to that specific secret; other secrets (e.g.
> git identity) are still deferred.

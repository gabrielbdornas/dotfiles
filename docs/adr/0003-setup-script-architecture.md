# 0003 - `setup.sh` → `bootstrap.sh` → `system.sh` → `user.sh`, no numeric prefixes

## Status

Accepted

## Context

The pre-existing `setup/` skeleton used numeric filenames
(`0_bootstrap.sh`, `1_system.sh`, `2_user.sh`) to make the run order
obvious from the filesystem, and `setup.sh` at the root was already
calling into them (albeit broken — see the "before" state below). A prior
design conversation (captured in `dotfiles_setup_conversation_summary.md`)
worked out a cleaner version of this same chain independently.

Before this decision, `setup.sh` line 44 called
`bash setup/0-bootstrap.sh` (hyphen) while the real file was
`setup/0_bootstrap.sh` (underscore) — a typo that meant running `setup.sh`
end-to-end failed immediately. There was also a repo-name typo
(`gabrielbdornass`, double s) left as an unresolved `# TODO` in two places.

## Decision

Both issues are fixed, and the numeric prefixes are dropped:
`bootstrap.sh`, `system.sh`, `user.sh`. Each script explicitly calls the
next one at the end of its own execution, so the run order is already
encoded in the code, not the filename — a number in the filename would be
redundant with that and one more thing to keep in sync if a step is ever
reordered or split.

Responsibilities, per the earlier design conversation:

- **`setup.sh`** (repo root) — the only script that must work *before* the
  repo is cloned. Resolves `REPO`/`REPO_URL`, installs `git` if missing
  (the one place package-manager detection is inlined rather than shared,
  since `setup/lib.sh` doesn't exist locally yet at this point), clones
  over HTTPS (see the "why HTTPS" reasoning captured in
  `dotfiles_setup_conversation_summary.md` §5 — no SSH key exists yet on a
  fresh machine), then hands off.
- **`bootstrap.sh`** — base OS packages, sudo, locale. Everything that has
  to exist before system- or user-level tools can be installed.
- **`system.sh`** — system-level tools not tied to a user identity
  (currently just GitHub CLI).
- **`user.sh`** — everything user-specific: shell, dotfiles, `gh`
  authentication, workspace directory, the sync service.

## Consequences

- `git` is installed exactly once, in `setup.sh`, before the clone — no
  script downstream re-installs it.
- Adding a new stage means adding a new script and one more `bash
  setup/<name>.sh` call at the end of the previous stage, not renumbering
  anything.
- Every stage is expected to be safely re-runnable (idempotent) end to
  end, since `setup/sync.sh` re-runs the whole chain from `bootstrap.sh`
  on every login (see
  [0007](0007-async-login-sync-defer-shutdown-autocommit.md)).

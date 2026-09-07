# 0007 - Sync on login only, async, via systemd; shutdown auto-commit deferred

## Status

Accepted

## Context

`main_idea.md` asked for machines to sync "smoothly," and floated two
triggers: running the pull+update on startup, and possibly even on the
lockscreen — with an explicit worry attached to both: "if on startup it
takes a long time, terrible experience." It also floated a shutdown-side
script that would check `git status`, prompt for (or AI-draft) a commit
message, and push before the machine goes down.

Three options were considered for the pull+apply trigger: synchronous at
shell/login startup (simplest, but exactly the blocking risk that was
flagged), a manual command only (zero infra, but sync only happens if
remembered), or async in the background at login with a desktop
notification.

## Decision

**Login sync, async, via a systemd user service.**
`setup/systemd/dotfiles-sync.service` (installed by `user.sh`) runs
`setup/sync.sh` once per login (`WantedBy=default.target`), not on a
timer and not tied to the lockscreen. `sync.sh` does `git pull --ff-only`
and re-runs `bootstrap.sh`, reporting success/failure via `notify-send`
rather than blocking anything.

**Shutdown-side auto-commit is out of scope for this pass entirely** —
including the AI-drafted-commit-message idea. It depends on infrastructure
that doesn't exist yet and was explicitly deferred rather than
half-built.

## Consequences

- Login is never slowed down by this — the friction concern from
  `main_idea.md` is resolved by construction, not by hoping the pull stays
  fast.
- A failed sync is visible (a desktop notification) but not blocking —
  you could in principle keep working on a machine that failed to sync and
  not notice until you see the notification.
- Local edits made on a machine are **not** automatically pushed anywhere
  by this pass. Pushing dotfile changes back to the repo is still a manual
  `git add/commit/push`, same as before this rewrite — "sync" so far is
  one-directional (repo → machine), not the full two-way loop
  `main_idea.md` ultimately wants.
- The lockscreen-triggered idea from `main_idea.md` is not implemented and
  isn't planned — login-triggered async sync was judged to already cover
  the actual intent (machines converge on repo state promptly) without the
  added complexity of hooking the lock/unlock flow.

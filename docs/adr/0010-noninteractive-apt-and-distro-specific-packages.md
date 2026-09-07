# 0010 - Non-interactive apt installs, and per-distro base package lists

## Status

Accepted

## Context

The first real Ubuntu-container test (see `docker/README.md`) surfaced two
bugs neither the local Arch machine nor `bash -n` could have caught:

1. `setup/bootstrap.sh`'s locale step called `sudo locale-gen en_US.UTF-8`,
   which failed with `locale-gen: command not found`. On Arch, `locale-gen`
   ships as part of `glibc` and is always present; on a minimal Ubuntu
   image it comes from the separate `locales` package, which wasn't in
   `BASE_PACKAGES`.
2. Installing `tree`/`vim`/etc. pulled in `tzdata` as a dependency, which
   triggered an interactive debconf prompt ("Please select the geographic
   area..."). It happened not to hang in that test run only by accident:
   during `curl | bash`, the script's stdin is the pipe carrying its own
   source, and once that pipe hit EOF, debconf's prompt had nothing left to
   read and fell back to its default. Running `bootstrap.sh` directly
   (not through a pipe, e.g. from `setup/sync.sh`'s re-run, or from inside
   the Docker test's interactive shell) would have a real terminal
   attached to stdin instead, and could genuinely block waiting for input.

## Decision

- `BASE_PACKAGES` is no longer a single list shared between apt and
  pacman - it's assigned per-distro in `setup/bootstrap.sh`, with
  `locales` added only for apt.
- Every apt install/remove call goes through
  `sudo env DEBIAN_FRONTEND=noninteractive apt ...` instead of plain
  `sudo apt ...` - in `setup/lib.sh:pkg_install()`, `setup.sh`'s git
  install, and `setup/system.sh`'s GitHub CLI install/gitsome removal.
  `env` is used specifically instead of a bare `sudo VAR=val` prefix,
  because whether `sudo` passes an inline `VAR=val` through to the command
  depends on the machine's sudoers `env_keep`/`env_reset` configuration;
  wrapping in `env` sets the variable unconditionally for apt's own
  process, entirely inside the already-privileged command sudo runs, with
  no dependency on that policy.

## Consequences

- Any apt-triggered debconf prompt (tzdata's, or a future package's) can
  no longer block a run, piped or not - it gets noninteractive's default
  answer instead of waiting on a stdin that may or may not be a real
  terminal.
- Adding a base package that only one distro needs (like `locales`) is now
  a one-line addition to that distro's case branch, not a shared list with
  an implicit "does this exist on both?" assumption baked in.
- This is exactly the kind of bug the Docker test (see `docker/`) exists
  to catch - day-to-day development happens on Arch, where neither of
  these two issues could have surfaced at all.

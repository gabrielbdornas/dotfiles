# 0002 - Multi-distro Linux support (apt + pacman), WSL as an independent axis

## Status

Accepted

## Context

The original `setup/0_bootstrap.sh` hard-exited on any system without
`apt`. The machine this rewrite is actually being developed and run on is
Arch Linux (`pacman`), so the apt-only assumption didn't even cover the
current machine, let alone "home and work" in general. `old_process/`
separately had ad-hoc WSL detection scattered in two different forms across
`zshrc` (checking `/proc/sys/kernel/osrelease` in one place and
`/proc/version` in another).

## Decision

Support Debian/Ubuntu (`apt`) and Arch (`pacman`) as the two package
managers, detected via `/etc/os-release`'s `ID` field
(`setup/lib.sh:detect_distro()`), not the `lsb_release` binary — the file
answers the same question with no extra dependency.

Treat WSL as a **second, independent axis**, not a third distro:
`setup/lib.sh:is_wsl()` is one canonical check
(`grep -qi microsoft /proc/version`), replacing the two different ad-hoc
checks in the old `zshrc`. A WSL Ubuntu box is still `apt`; a WSL Arch box
is still `pacman`. Distro detection already covers package installation on
either; `is_wsl()` exists for the separate concerns that have nothing to do
with package managers (Windows interop, launching Windows binaries, etc.),
which are out of scope for this pass (see
[0008](0008-infra-only-scope-for-this-pass.md)) but will need this helper
when that content gets migrated.

## Consequences

- Every install step in `bootstrap.sh`/`system.sh` branches on
  `detect_distro()`'s result, including package-name differences (e.g.
  GitHub CLI is `gh` on apt via a custom repo, `github-cli` on pacman
  directly from the official repos).
- macOS is explicitly not supported by this process. `old_process/`
  remains the reference for whatever macOS-specific behavior existed
  there.
- Any future distro needs one more case in `detect_distro()`, not a
  rewrite of the calling scripts.

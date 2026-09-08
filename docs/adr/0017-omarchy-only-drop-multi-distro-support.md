# 0017 - Drop multi-distro (apt) support entirely, require Omarchy specifically

## Status

Accepted

## Context

`setup/` was built to support both apt (Debian/Ubuntu/Pop!_OS) and pacman
(Arch/Omarchy) machines, validated by three Docker images
(`ubuntu-test.Dockerfile`, `arch-test.Dockerfile`, `omarchy-test.Dockerfile`)
and documented across roughly fifteen ADRs by this point. The real machine
matrix turned out to be: a personal machine on Omarchy (the one being
invested in, per [0016](0016-omarchy-only-not-a-desktop-dispatcher.md)), a
work machine on Pop!_OS (apt-based, not settled whether it stays), and an
earlier idea of supporting colleagues on Ubuntu-in-WSL that 0016 already
shelved.

This applies the same principle 0016 used for desktop config (build for
the real target, not hypothetical ones) one layer down, to the OS/bootstrap
layer itself - the apt branch had become a real, measurable maintenance
cost (`gh`'s key+repo dance, `DEBIAN_FRONTEND` workarounds, the `locales`
package quirk, a whole separate Docker image and README section, three
ADRs largely or entirely about apt-specific problems) serving a target that
might never actually run it.

Confirmed by direct inspection before deciding anything: `is_wsl()` in
`setup/lib.sh` was already fully dead code - defined, never called
anywhere - independent of this decision.

Decided via explicit tradeoff discussion, not assumed:
- **Pop!_OS gets zero automated setup from this tool going forward** -
  not even the desktop-independent shell/tooling layer (git, gh, jq,
  infisical, Oh My Zsh, SSH key setup), none of which was ever
  Omarchy-specific. Explicitly accepted, not an oversight - `old_process/`
  or manual setup covers it until/unless that machine migrates to Omarchy.
- **`setup.sh` requires Omarchy specifically**, not just any Arch-family
  machine. Plain (non-Omarchy) Arch is now rejected outright too - a
  stricter stance than "Omarchy dotfiles are an extra gated step," which
  is what [0016](0016-omarchy-only-not-a-desktop-dispatcher.md) alone
  would have left in place.
- **Docker tests consolidate to `omarchy-test.Dockerfile` only.**

## Decision

**Enforced in two places**, not one - `setup/bootstrap.sh` (and therefore
`user.sh`) can run without ever going through `setup.sh` first:
`setup/sync.sh` re-runs `bootstrap.sh` directly on every login, and the
Docker "quick iteration" testing flow always has too.

1. `setup.sh` gains a hard requirement immediately after its existing
   `REPO`/`INFISICAL_*` fail-fast checks:
   ```bash
   if ! ( . /etc/os-release; [ "$ID" = "omarchy" ] ); then
     echo "This only supports Omarchy machines. See docs/adr/0017." >&2
     exit 1
   fi
   ```
   (a subshell, so `/etc/os-release`'s other fields don't leak into the
   script's own variables). This is inlined rather than calling
   `is_omarchy()` because `setup/lib.sh` doesn't exist yet at this point -
   same reasoning already used for git/gh/jq/infisical there.
2. `setup/bootstrap.sh` adds `is_omarchy() || exit 1` right after sourcing
   `lib.sh`, closing the gap for the sync/direct-invoke path using the
   shared, already-existing check from
   [0016](0016-omarchy-only-not-a-desktop-dispatcher.md) - which is *not*
   made redundant by setup.sh's new check, since it protects a genuinely
   different invocation path.
3. Every apt/pacman branch is removed - `setup.sh`'s `EARLY_PKG_MGR`
   detection, `setup/lib.sh`'s `detect_distro()` and the case statement in
   `pkg_install()`, `setup/bootstrap.sh`'s `DISTRO_MGR` branching - replaced
   by direct, unconditional `pacman` calls throughout, since Omarchy is
   guaranteed Arch-derived once the check above passes. `gh`'s entire apt
   key+repo+`gitsome`-removal dance is deleted outright (`github-cli` is a
   normal Arch package, no setup needed); Infisical's apt install branch
   (`setup.deb.sh`) is deleted, keeping only the pre-existing Arch
   `.pkg.tar.zst`-via-GitHub-releases logic, which was always
   Arch-specific and unrelated to this cleanup.
4. `docker/ubuntu-test.Dockerfile` and `docker/arch-test.Dockerfile` are
   deleted. `docker/omarchy-test.Dockerfile` needed no changes - it already
   overwrote `/etc/os-release` with `ID=omarchy` and never preinstalled
   `git`, so it already satisfied the stricter requirement.

## Consequences

- Significant code reduction: almost no branching remains anywhere in the
  bootstrap chain.
- Pop!_OS (or any future apt-based machine) cannot run this tool at all,
  not even for the generic shell/tooling layer - a deliberate, accepted
  gap, not a bug to report.
- Plain, non-Omarchy Arch machines are now also explicitly rejected by
  `setup.sh`, not just missing the desktop-specific dotfiles the way
  [0016](0016-omarchy-only-not-a-desktop-dispatcher.md) alone would have
  left them.
- If apt support, or generic (non-Omarchy) Arch support, is ever needed
  again, this ADR plus the ones it supersedes
  ([0002](0002-multi-distro-linux-support.md),
  [0010](0010-noninteractive-apt-and-distro-specific-packages.md),
  [0013](0013-guard-missing-systemctl-in-user-sh.md)) remain as a complete
  historical reference for how it worked before - nothing was deleted from
  history, only from the current code.

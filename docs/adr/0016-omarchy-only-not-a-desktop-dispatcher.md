# 0016 - Gate Omarchy dotfiles with `is_omarchy()`, not a general desktop dispatcher

## Status

Accepted

## Context

The real machine matrix turned out to be: a personal machine on Omarchy
(new, and the one being invested in going forward), a work machine on
Pop!_OS (GNOME/COSMIC-based, not settled whether it stays), and an earlier
idea of also supporting colleagues on Ubuntu-in-WSL to "unify the work
process" more broadly.

A `detect_desktop()`-style dispatcher was drafted in conversation - auto-detect
`omarchy`/`gnome`/`none` from real signals (`is_wsl()`, `/etc/os-release`'s
`ID`, an Omarchy marker directory), with per-environment dotfile
directories (`config/omarchy/`, `config/gnome/`, ...) and `user.sh` picking
which set to link based on the result.

That was reconsidered before being built: the WSL-colleagues goal was
dropped as premature, Pop!_OS's future on the work machine is unresolved,
and no GNOME/Pop!_OS-flavored dotfiles exist to link yet regardless. Building
a general multi-environment dispatch framework to serve exactly one real,
committed target (Omarchy) is solving a problem that doesn't exist yet at
the cost of code nothing currently exercises.

## Decision

Just `is_omarchy()` - one boolean check in `setup/lib.sh`, mirroring the
existing `is_wsl()` pattern:

```bash
is_omarchy() {
  # shellcheck disable=SC1091
  source /etc/os-release
  [ "$ID" = "omarchy" ]
}
```

`/etc/os-release`'s `ID` field is the standard mechanism for exactly this -
the same one `detect_distro()` already reads for Debian/Ubuntu/Arch - and
Omarchy declares itself there directly (`ID=omarchy`, `ID_LIKE=arch`,
confirmed by hand on a real machine). This went through two worse attempts
first, both app-data-directory guesses: `$HOME/.local/share/omarchy`
(lowercase, read from `OMARCHY_PATH` in Omarchy's own `install.sh`) didn't
match reality; the real directory turned out to be
`$HOME/.local/share/Omacom` (capital O) instead - which itself was still
the wrong *kind* of signal to depend on, compared to an officially declared
identity field. Neither directory guess was ever committed - the lesson
(prefer a standard, documented identity mechanism over reverse-engineering
a directory name) is worth keeping regardless.

`ID_LIKE=arch` also confirms `detect_distro()` already handles Omarchy
correctly with no changes needed: `ID=omarchy` doesn't match its `arch`
case directly, but falls through to the `ID_LIKE` check and correctly
resolves to `pacman`.

`setup/user.sh`'s dotfile-linking step is gated on `is_omarchy()` directly:

```bash
if is_omarchy; then
  # link config/hypr/*.conf
else
  echo "-----> Not an Omarchy machine - skipping Omarchy-specific dotfiles"
fi
```

`docker/omarchy-test.Dockerfile` now overwrites `/etc/os-release` with a
real Omarchy machine's actual content (`archlinux:latest` reports plain
`ID=arch` by default), so the Docker test actually exercises this branch
instead of silently taking the `else` path.

No `DOTFILES_PROFILE` involvement, no per-environment directory structure,
no dispatch table - those get built only if/when a second real desktop
environment actually needs dotfiles of its own.

## Consequences

- Pop!_OS and WSL machines get the shared shell/tooling layer (Oh My Zsh,
  plugins, git/gh/jq/infisical setup) and nothing desktop-specific - which
  is already correct for both today, not a gap.
- If the work machine moves to Omarchy later, it picks up the Omarchy
  dotfiles automatically with zero additional code - `is_omarchy()` doesn't
  care which machine it's asked on.
- If a second real desktop environment does need its own dotfiles someday,
  this pattern extends by adding one more `is_<thing>()` check next to
  `is_omarchy()`, not by retrofitting a dispatcher that was built
  speculatively.
- The "unify colleagues' WSL setup" idea is shelved, not designed around -
  revisit if it becomes a real goal again, rather than pre-building for it.

> **Update ([0017](0017-omarchy-only-drop-multi-distro-support.md)):**
> the tradeoff above ("Pop!_OS and WSL machines get the shared shell/tooling
> layer... which is already correct for both today") no longer holds - 0017
> went further and dropped apt support entirely, so Pop!_OS gets nothing at
> all now, not even that shared layer. This ADR's own decision
> (`is_omarchy()` gates the desktop dotfiles) is unchanged and still
> correct; `is_wsl()` referenced above was removed in 0017 as well (it was
> already fully dead code, unrelated to this ADR's reasoning).

# 0015 - Omarchy run confirms 0014 is environment-wide, not Arch-specific; the symlink collision path is still untested

## Status

Proposed (logged for next session, not fixed yet - confirms [0014](0014-confirmed-systemctl-session-bus-missing-in-containers.md))

## Context

Same `setup.sh` run against `dotfiles-omarchy-test` as the Arch run in
[0014](0014-confirmed-systemctl-session-bus-missing-in-containers.md):
git/gh/jq/infisical, Infisical auth, SSH key, clone, `bootstrap.sh`, Oh My
Zsh, both plugins, and both `config/hypr/*.conf` symlinks all completed,
then the identical failure on the same line:

```
Failed to connect to user scope bus via local transport: $DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR not defined (consider using --machine=<user>@.host --user to connect to bus of other user)
```

Unsurprising - both `dotfiles-arch-test` and `dotfiles-omarchy-test` are
built `FROM archlinux:latest`, so this is confirmation the 0014 issue is
about the container environment (no login session/dbus), not anything
specific to plain Arch vs. Omarchy's image. No new information there,
0014's decision stands unchanged.

What's worth logging separately: the "Linking example dotfiles" step
succeeded with **no** backup/warning output, even though
`dotfiles-omarchy-test` seeds `~/.config/hypr` with Omarchy's real default
config before `setup.sh` ever runs (see `docker/omarchy_test.Dockerfile`).
This is expected, not a bug - flagged in that Dockerfile's own comment
already: Omarchy's real hypr config is Lua-based (`bindings.lua`,
`input.lua`, ...), so it doesn't share exact filenames with
`config/hypr/keybindings.conf`/`monitors.conf`. `link_dotfile()` just hit
its "target doesn't exist" case (create the symlink) for both files, same
as it would on a machine with no pre-existing hypr config at all.

The actual point of the Omarchy image - exercising `link_dotfile()`'s
backup-and-warn collision path from [0006](0006-symlink-safety-for-externally-managed-configs.md)
against a real pre-existing file - has therefore **still never been tested
by any of the three Docker images**. It's the one piece of 0006's design
that's been sitting unverified since it was written.

## Decision (for next session)

Actually exercise the collision path, either:

- Rename one of the two example dotfiles to a name Omarchy's real config
  uses (none currently match - `bindings.lua`/`input.lua`/etc. under
  `default/hypr`, not `.conf` files), so a real collision occurs naturally
  when `setup.sh` runs against the seeded image, or
- Have `docker/omarchy_test.Dockerfile` additionally pre-create a file at
  the exact path `config/hypr/keybindings.conf` or `monitors.conf` targets
  (`~/.config/hypr/keybindings.conf`), with content that deliberately
  differs from the repo's version, purpose-built to force the collision
  branch regardless of what Omarchy's own files are named.

The second option is more direct and doesn't depend on Omarchy's real
filenames (which could change upstream); worth deciding which one actually
matches what "testing against Omarchy" is meant to validate.

## Consequences

- Until this is done, [0006](0006-symlink-safety-for-externally-managed-configs.md)'s
  core safety behavior - the reason `link_dotfile()` backs up instead of
  overwriting a diverged real file - remains logic that's only been
  verified by the scratch smoke test run manually before the Docker tests
  existed (three synthetic cases in a scratchpad dir), not by any automated
  or repeatable test.
- [0014](0014-confirmed-systemctl-session-bus-missing-in-containers.md)'s
  fix, once implemented, should be verified against both the Arch and
  Omarchy images - this run confirms they'll behave identically for that
  specific check, so one passing likely means both do, but worth confirming
  rather than assuming.

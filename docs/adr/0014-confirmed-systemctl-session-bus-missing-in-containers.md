# 0014 - Confirmed: `systemctl` can exist but fail to connect to a user session bus

## Status

Accepted (implemented in `setup/user.sh` - extends [0013](0013-guard-missing-systemctl-in-user-sh.md))

## Context

Running the same `setup.sh` flow validated in
[0012](0012-authenticate-before-cloning-into-code-dir.md) against the new
`dotfiles-arch-test` image (`docs/adr/`'s Arch Docker test, added after
0013) got further than the Ubuntu run did - git/gh/jq/infisical install,
Infisical auth, SSH key, clone, `bootstrap.sh`, Oh My Zsh, both zsh plugins,
and both `config/hypr/*.conf` symlinks all completed - but `user.sh`'s
systemd step still failed, on a different line than 0013's Ubuntu failure:

```
Failed to connect to user scope bus via local transport: $DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR not defined (consider using --machine=<user>@.host --user to connect to bus of other user)
```

Unlike Ubuntu's minimal image, Arch's official Docker image apparently
includes `systemctl` itself (systemd is part of Arch's base system, not a
separate opt-in package the way it can be on minimal Debian/Ubuntu images) -
so [0013](0013-guard-missing-systemctl-in-user-sh.md)'s planned
`command -v systemctl` guard would NOT catch this failure at all: the
binary exists here, `systemctl --user enable --now` runs, and only then
fails because there's no actual user session (no `$DBUS_SESSION_BUS_ADDRESS`,
no `$XDG_RUNTIME_DIR` - both normally set up by a real login session, which
a container obviously doesn't have).

This is exactly the failure mode 0013 already flagged as an open question
("worth deciding... whether this should also detect the 'systemctl exists
but no user session available' case") - now confirmed happening for real,
not hypothetical.

## Decision

`user.sh`'s systemd guard needs to check both conditions, not just the
binary's existence:

```bash
if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
  echo "===> Installing dotfiles-sync systemd unit..."
  # ... existing install/enable steps ...
else
  echo "-----> No usable systemd user session - skipping login-sync service install (expected in containers/minimal environments)"
fi
```

`systemctl --user status` is a reasonable existence-of-session probe:
it needs a reachable user bus to succeed at all, so it fails cleanly in
exactly the container scenario seen here, without depending on parsing the
specific "$DBUS_SESSION_BUS_ADDRESS...not defined" error text.

## Consequences

- Confirms 0013's fix needs both checks combined, not just
  `command -v systemctl` - a binary-only guard would still fail loudly on
  Arch-like containers/environments where systemd is installed but no
  session exists.
- Reinforces that this is genuinely a "different environments fail
  differently" problem: Ubuntu's minimal image is missing the binary
  entirely, Arch's has the binary but no session. Any fix needs to handle
  both, not just the one first observed.
- Everything before this step remains proven working on Arch now too,
  same as 0013 noted for Ubuntu - this is the last step in the chain.

> **Update:** implemented exactly as proposed above, in `setup/user.sh`'s
> final step, and confirmed against a real `docker/omarchy_test.Dockerfile`
> run (both the full `setup.sh` one-liner and a same-container rerun): the
> log now ends with `-----> No usable systemd user session - skipping
> login-sync service install (expected in containers/minimal environments)`
> followed by `===> User setup complete`, exit 0 - the first time the full
> script has completed end to end without failing on this step.
> [0013](0013-guard-missing-systemctl-in-user-sh.md)'s own guard was never
> separately implemented - this single check supersedes it, since it
> already covers both failure modes (binary missing, and binary present
> but no session).

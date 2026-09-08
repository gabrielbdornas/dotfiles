# 0018 - Use `uname -n`, not `hostname`, for SSH key naming

## Status

Accepted

## Context

Reviewing the full log of a real Omarchy Docker test run (and its rerun)
surfaced `hostname: command not found` twice, at `setup.sh`'s SSH key
generation and registration steps:

```bash
ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "$(whoami)@$(hostname)"
...
gh ssh-key add "$SSH_KEY.pub" --title "$(hostname)"
```

`hostname` isn't part of Arch/Omarchy's base install - it ships in the
separate `inetutils` package, which nothing in this repo installs. The
command fails, but neither call site's failure was caught by
`set -euo pipefail`: both use `$(hostname)` nested inside a larger string
argument (an `-C` comment, a `--title` value), so the failing exit status
is discarded once the (empty) output is spliced into that string - only
the outer `ssh-keygen`/`gh` command's own exit status is checked, and both
succeeded regardless.

Confirmed real-world effect: the SSH key generated during testing got a
blank-hostname comment (`tester@` instead of `tester@<hostname>`), and
more importantly `gh ssh-key add --title "$(hostname)"` registered the key
on the real GitHub account with an **empty title**. The user checked
github.com/settings/keys after both the initial run and a rerun and found
exactly one such key - confirming the existing "already registered"
idempotency check (matching `gh`'s "already in use" error text) worked
correctly on the second run, and ruling out the earlier suspicion (raised
before this check) that repeated test runs might be silently accumulating
duplicate keys.

## Decision

Replace both `$(hostname)` calls with `$(uname -n)`. `uname` is part of
coreutils, a hard dependency of essentially everything - always present,
no daemon or session required. `hostnamectl` was considered and rejected:
it talks to `systemd-hostnamed` over D-Bus, and this exact container
already can't reach a systemd user session bus (`docs/adr/0014`) - using
it here would trade one missing-binary failure for a different D-Bus
failure. `uname -n` has no such dependency and is a drop-in replacement
for `hostname`'s default (no-argument) output.

## Consequences

- Both `setup.sh` call sites now resolve a hostname using only coreutils,
  with no external package dependency.
- The blank-titled key already registered on the user's GitHub account
  from before this fix is not touched automatically - cleaning it up (or
  not) is a manual, optional step at github.com/settings/keys, not
  something the script itself attempts.
- General lesson worth carrying forward: a failing command nested inside
  a command substitution used as part of a larger string argument is
  invisible to `set -e` - only the outer command's exit status counts.
  Any future external-command usage in this pattern (`"$(cmd)"` spliced
  into a larger argument) should get the same scrutiny this one didn't.

# 0009 - Require `REPO` via `export`, fail fast instead of a hardcoded default

## Status

Accepted

## Context

`setup.sh` originally had `REPO="${REPO:-gabrielbdornas/dotfiles}"` — if
`REPO` wasn't set, it silently fell back to this specific personal
repo/username. That's not a secret (the repo is public, and its path is
already visible in whatever URL you type to fetch `setup.sh` in the first
place), but hardcoding one person's identity into otherwise-reusable
infrastructure code was judged undesirable on principle.

Two real constraints shaped the alternative:

- `curl -fsSL <url> | bash` streams the script straight into a *new* `bash`
  process's stdin. A plain (non-exported) shell variable set before that
  command — `REPO="x"` — does **not** reach that child process; only an
  `export`ed variable does. This was verified directly: piping a probe
  script into `bash` after a plain `REPO="foo/bar"` came back
  `REPO=<unset>` inside the child; after `export REPO="foo/bar"`, it came
  back correctly.
- An actual interactive prompt was considered too (asking the user for
  `REPO` when it's missing), but during `curl | bash` the script's stdin
  *is* the pipe carrying its own source — a normal `read` would consume
  script bytes instead of terminal input. A real prompt needs to read from
  `/dev/tty` explicitly, which only works when a terminal is actually
  attached (fails under CI, or `docker run` without `-it`). This was ruled
  out as unnecessary complexity for what's fundamentally a one-word fix
  (`export`).

## Decision

Drop the default. Require `REPO` and fail immediately with a clear message
if it's missing, using bash's `${VAR:?message}` form:

```bash
: "${REPO:?REPO is required. Set it, e.g.: export REPO=\"yourname/dotfiles\"}"
```

The documented usage becomes:

```bash
export REPO="yourname/dotfiles" && curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/setup.sh" | bash
```

`export` is required, not optional, because `${REPO}` inside the URL is
expanded by the *calling* shell before `curl` even runs (works either
way), but `setup.sh` itself runs in the piped-into child process, which
only inherits exported variables.

## Consequences

- No personal repo path lives in the script anymore — every installer
  needs to explicitly say which repo it's installing, including for the
  repo's own primary user.
- You now always type the repo path twice in the one-liner: once in the
  `curl` URL (unavoidable — that's how `curl` finds the file), once in
  `export REPO=...`. There's no way for `setup.sh` to recover the URL it
  was fetched from and infer the second one automatically.
- Forgetting `export` (or writing a plain `REPO=...` instead) now fails
  loudly with a clear message, instead of silently installing whatever the
  old hardcoded default was.

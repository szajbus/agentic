# {{PROJECT_NAME}} devcontainer

A reproducible, sandboxed development environment for {{PROJECT_NAME}}.
Everything needed to build, run, and test — toolchain, services, and tooling —
runs in containers. Your host stays clean, and (deliberately) your SSH keys and
push credentials stay on the host. See [Git: identity in, secrets
out](#git-identity-in-secrets-out).

This is a standard [Dev Container](https://containers.dev) (a
`devcontainer.json` backed by Docker Compose), so it works with any editor or
CLI that speaks the spec — it does **not** assume VS Code.

## What's inside

The `app` container:

- Runs as a non-root `dev` user (UID/GID aligned to the host on start).
- Bind-mounts the repo at `/workspace` — so the container and host share the
  **same working tree and `.git`**.
- Exposes the app server on `127.0.0.1:${PORT:-{{DEFAULT_PORT}}}` (loopback only).
- Ships delta, fzf, ripgrep, fd, jq, tmux, zsh + Oh My Zsh, and the Claude Code CLI.
- On first create, runs `post_install.sh`: bootstraps the project and configures
  git, tmux, and Claude Code.

### Persistence

Named volumes survive rebuilds:

- `commandhistory` — shell history
- `claude-config` — Claude Code config/auth
- `gh-config` — GitHub CLI config
- the shared, **external** toolchain caches listed under
  [Prerequisites](#prerequisites)

## Prerequisites

- Docker (Docker Desktop, OrbStack, or compatible).
- The shared external cache volumes (one-time, or `compose up` will fail with
  "volume … could not be found"):
  ```sh
  # Create one volume per shared cache the project uses:
  # docker volume create {{PROJECT_SLUG}}-<name>-cache
  ```
- Optional, for the editor-neutral CLI: `npm i -g @devcontainers/cli`.

## Bringing it up

The simplest path is the bundled lifecycle helper, which handles project naming,
free-port selection, and shared volumes for you:

```sh
bin/worktree up        # build + start + run post-create
bin/worktree status    # show stack status
bin/worktree down      # stop + remove per-project volumes (caches survive)
```

### Alternatives

- **An editor that supports dev containers (Zed, VS Code, …):** open the project
  and "reopen in container". The editor reads `devcontainer.json`, builds the
  image, and runs `post_install.sh`.
- **The `devcontainer` CLI directly:** `devcontainer up` then
  `devcontainer exec zsh` (run from the repo root).
- **Plain `docker compose`:** works, but does **not** apply `devcontainer.json`
  (no token forwarding, no `updateRemoteUserUID`, and `postCreateCommand` is not
  run — you'd run `/opt/post_install.sh` yourself).

Override the port by exporting `PORT` before bringing the container up, or pass
`--port` to `bin/worktree up`.

## Configuration

### Claude Code auth

`CLAUDE_CODE_OAUTH_TOKEN` and `ANTHROPIC_API_KEY` are forwarded from your host
environment (via `remoteEnv`) when set; auth also persists in the
`claude-config` volume. In this container Claude runs in **`bypassPermissions`**
mode (no per-action prompts) — see the security section below.

### Network binding

The app port is published to the host as `127.0.0.1:${PORT}` — **loopback only**,
never the LAN. Inside the container the server binds `0.0.0.0` (required for
Docker's port forward to reach it), driven by the `BIND_HOST` env var that compose
sets. The project's committed config defaults `BIND_HOST` to `127.0.0.1`, so if
you run the dev server **directly on the host** it stays on loopback. Don't
hardcode `0.0.0.0` in app config.

### Commit identity

Set once per clone (see [Git: identity in, secrets out](#git-identity-in-secrets-out)):

```sh
git config --local user.name  "Your Name"
git config --local user.email "you@example.com"
```

This writes to the repo's `.git/config`, which is bind-mounted — so the **same**
identity applies on the host and in the container, with no extra wiring.

## Git: identity in, secrets out

This is a deliberate security boundary. Inside the container, Claude Code runs
with **`bypassPermissions`** — it can execute commands with no approval prompts.
To bound what a runaway or compromised agent could do, the container is given
**no way to act as you against a remote, or to forge your signature**:

- **No SSH agent, no SSH private keys, and no host `~/.gitconfig`** are mounted.
- **No push/pull credentials** live in the container.
- The container can only **read history and create local, unsigned commits.**

What *is* provided:

- **Commit identity** — set per-repo with `git config --local` (see
  [Commit identity](#commit-identity)). It lives in the bind-mounted
  `.git/config`, so host and container share one value. If unset, commits fail
  loudly until you set it.
- A **self-contained git config** (`~/.gitconfig.local`: delta pager, diff/merge
  settings). No host config leaks in.

**Fetch / pull / push** and **commit signing** happen on the **host**, where
your keys live and where *you* — not the agent — trigger the action.

### Workflow: commit in the container, sign + push on the host

Because the repo is bind-mounted, the container and host share the same `.git`,
so a commit made in the container is immediately visible on the host — no
copying.

1. In the **container**, work and commit normally (unsigned, attributed via
   your `git config --local` identity):

   ```sh
   git add -A
   git commit -m "Your message"
   ```

2. On the **host**, in the same repo, sign and push. This assumes your host git
   is set up for SSH commit signing (`gpg.format=ssh`, `user.signingkey`,
   `commit.gpgsign=true`) with your SSH agent available.

   Sign just the latest commit:

   ```sh
   git commit --amend --no-edit -S
   git push
   ```

   Sign every commit you made since `origin/main` (re-signs each):

   ```sh
   git rebase --exec 'git commit --amend --no-edit -n -S' origin/main
   git push
   ```

   Verify:

   ```sh
   git log --show-signature -1
   ```

If you don't sign commits at all, just `git push` from the host — the point is
that remote access and key material stay host-side.

### Git worktrees

This setup works when the project is a **linked git worktree**, not just a main
clone. A worktree's `.git` is only a pointer into the main repo's
`.git/worktrees/<name>`, which lives outside the worktree directory — so it isn't
in the `/workspace` bind, and without help git inside the container can't find
the object store (commits/log/status fail).

`bin/worktree up` handles this automatically: it resolves the git common dir (the
main repo's `.git`) and the worktree's own path and mounts both into the container
**at their real host paths**, so git just works. Those paths are written to
`.devcontainer/.env` (gitignored). Caveats:

- Bring the container up with **`bin/worktree up`** (not raw `docker compose`), so
  the paths get computed and written.
- If you **move** the worktree on the host, re-run `bin/worktree up` to refresh
  the mounts.
- The main repo's `.git` is mounted read-write (commits write to the shared
  object store). Still no SSH keys, host `~/.gitconfig`, or push credentials —
  push and signing remain host-side, as above.

## Troubleshooting

- **`Author identity unknown` / `unable to auto-detect email address` on
  commit** — commit identity isn't set for this repo. Run the two
  `git config --local` commands from [Commit identity](#commit-identity).
- **`volume "…" could not be found`** — create the external cache volumes (see
  [Prerequisites](#prerequisites)).
- **Port already in use** — set `PORT` to a free port, or let `bin/worktree up`
  pick one.
- **Claude asks you to log in** — ensure `CLAUDE_CODE_OAUTH_TOKEN` (or
  `ANTHROPIC_API_KEY`) is exported in the environment that launches the
  container, or authenticate once inside (persists in `claude-config`).

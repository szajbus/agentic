# Agentic Skills devcontainer

A reproducible, sandboxed environment for working on this repo's skills — built
so an unattended coding agent (Claude Code in `bypassPermissions`) can edit,
restructure, and experiment with skills **freely** without touching your host.
Your host stays clean, and (deliberately) your SSH keys and push credentials stay
on the host. See [Git: identity in, secrets out](#git-identity-in-secrets-out).

This is a standard [Dev Container](https://containers.dev) (a `devcontainer.json`
backed by Docker Compose), so it works with any editor or CLI that speaks the
spec — it does **not** assume VS Code.

## What's inside

The `app` container:

- Runs as a non-root `dev` user (UID/GID aligned to the host on start).
- Bind-mounts the repo at `/workspace` — so the container and host share the
  **same working tree and `.git`**.
- Is minimal Debian: git + core CLI tooling (delta, fzf, ripgrep, fd, jq, tmux,
  zsh + Oh My Zsh) + the Claude Code CLI. **No language runtime** — this repo is
  markdown/shell skills; install a runtime ad hoc inside the container if a skill
  experiment needs one (`sudo apt-get install …`).
- Publishes `127.0.0.1:${PORT:-4400}` (loopback only) in case a skill experiment
  spins up a dev server; nothing listens there by default.
- On first create, runs `post_install.sh`: configures git, tmux, and Claude Code.

### Persistence

Named volumes survive rebuilds:

- `commandhistory` — shell history
- `claude-config` — Claude Code config/auth
- `gh-config` — GitHub CLI config

There are no shared toolchain caches (nothing to cache — no dependency manager).

## Prerequisites

- Docker (Docker Desktop, OrbStack, or compatible).
- For the editor-neutral CLI: `npm i -g @devcontainers/cli`.

Then run the one-time, per-clone setup:

```sh
bin/devcontainer setup
```

It seeds your commit identity by copying `user.name`/`user.email` from your
global git config into this repo's local `.git/config` (or tells you how to set it
if your global config has none — see [Commit identity](#commit-identity)), and
checks Docker is running. It's idempotent, so re-run it any time.

## Bringing it up

The bundled lifecycle helper handles project naming, free-port selection, and the
git-worktree mounts for you:

```sh
bin/devcontainer up            # build + start + run post-create
bin/devcontainer status        # show stack status
bin/devcontainer down          # tear down this checkout's stack
bin/devcontainer down --caches # (no shared caches here — same as down)
```

`down` removes this checkout's containers, network, and per-project volumes
(history, agent/gh config) and deletes `.devcontainer/.env`. Run it **before**
deleting a worktree directory — once the directory is gone, so is this script.

Open a shell and run the agent inside:

```sh
devcontainer exec zsh
# then, in the container:
claude            # already in bypassPermissions mode
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

## Configuration

### Claude Code auth

`CLAUDE_CODE_OAUTH_TOKEN` and `ANTHROPIC_API_KEY` are forwarded from your host
environment (via `remoteEnv`) when set; auth also persists in the `claude-config`
volume. In this container Claude runs in **`bypassPermissions`** mode (no
per-action prompts) — see the security section below.

### Commit identity

`bin/devcontainer setup` seeds this for you by copying `user.name`/`user.email`
from your global git config. To set or change it by hand (see [Git: identity in,
secrets out](#git-identity-in-secrets-out)):

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

**Fetch / pull / push** and **commit signing** happen on the **host**, where your
keys live and where *you* — not the agent — trigger the action.

### Workflow: commit in the container, sign + push on the host

Because the repo is bind-mounted, the container and host share the same `.git`,
so a commit made in the container is immediately visible on the host — no copying.

1. In the **container**, work and commit normally (unsigned, attributed via your
   `git config --local` identity):

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

If you don't sign commits at all, just `git push` from the host — the point is
that remote access and key material stay host-side.

### Git worktrees

This setup works when the project is a **linked git worktree**, not just a main
clone. A worktree's `.git` is only a pointer into the main repo's
`.git/worktrees/<name>`, which lives outside the worktree directory — so it isn't
in the `/workspace` bind, and without help git inside the container can't find the
object store (commits/log/status fail).

`bin/devcontainer up` handles this automatically: it resolves the git common dir
(the main repo's `.git`) and the worktree's own path and mounts both into the
container **at their real host paths**, so git just works. Those paths are written
to `.devcontainer/.env` (gitignored). Caveats:

- Bring the container up with **`bin/devcontainer up`** (not raw `docker
  compose`), so the paths get computed and written.
- If you **move** the worktree on the host, re-run `bin/devcontainer up` to
  refresh the mounts.
- The main repo's `.git` is mounted read-write (commits write to the shared
  object store). Still no SSH keys, host `~/.gitconfig`, or push credentials —
  push and signing remain host-side, as above.

## Troubleshooting

- **`Author identity unknown` / `unable to auto-detect email address` on
  commit** — commit identity isn't set for this repo. Run the two
  `git config --local` commands from [Commit identity](#commit-identity).
- **Port already in use** — set `PORT` to a free port, or let `bin/devcontainer
  up` pick one.
- **Claude asks you to log in** — ensure `CLAUDE_CODE_OAUTH_TOKEN` (or
  `ANTHROPIC_API_KEY`) is exported in the environment that launches the
  container, or authenticate once inside (persists in `claude-config`).

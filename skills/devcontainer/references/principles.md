# Principles — why this devcontainer is shaped the way it is

The files are easy to copy. The reasoning is the part worth preserving. Read
this before generating, and carry the relevant bits into the generated README so
the next person understands the boundary they're relying on.

## 1. Git: identity in, secrets out (the centerpiece)

The container runs a coding agent in `bypassPermissions` — it executes commands
with **no approval prompts**. The safety model is not "trust the agent"; it's
"bound what the agent can do." The boundary is git:

- **No SSH agent, no SSH private keys, no host `~/.gitconfig` is mounted.**
- **No push/pull credentials live in the container.**
- The container can **read history and create local, unsigned commits — nothing
  more.**

So a runaway or compromised agent cannot push to a remote, cannot act as you
against GitHub, and cannot forge your commit signature. The worst it can do is
make local commits in a working tree you already control.

What *is* provided inside the container:

- **A self-contained git config** at `~/.gitconfig.local`, pointed to by
  `GIT_CONFIG_GLOBAL`. It carries container-only conveniences (delta pager,
  diff/merge style, a global gitignore) and deliberately **does not** inherit
  anything from the host. Nothing leaks in.
- **Commit identity**, set per-repo with `git config --local user.name/email`.
  This writes to the repo's `.git/config`, which is bind-mounted — so the same
  identity applies on host and in container with no extra wiring. If unset,
  commits fail loudly (by design) until the user sets it.

The intended workflow: **commit in the container, sign + push on the host.**
Because the repo is bind-mounted, a commit made in the container is immediately
visible on the host — no copying. On the host (where the keys live and where a
*human* triggers the action), you sign and push:

```sh
# sign just the latest commit
git commit --amend --no-edit -S && git push

# or re-sign every commit since origin/main
git rebase --exec 'git commit --amend --no-edit -n -S' origin/main && git push
```

This is the single most important idea in the whole setup. Preserve it verbatim.

## 2. bypassPermissions, bounded by the git boundary

The two decisions are a pair. Running the agent unattended is only reasonable
*because* principle #1 caps the blast radius. In post-create, the agent's
settings are set to `permissions.defaultMode = "bypassPermissions"` and its
onboarding is bypassed (seed auth via a throwaway `claude -p`, then flip
`hasCompletedOnboarding`). Auth tokens are **forwarded from the host env** via
`remoteEnv` (`CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_API_KEY`) and persisted in a
named volume — they are not baked into the image.

## 3. Non-root user, host UID/GID aligned

The container runs as a non-root `dev` user with `NOPASSWD` sudo for
convenience. `remoteUser` + `updateRemoteUserUID` align the in-container UID/GID
to the host user, so files created in the bind-mounted workspace have correct
host ownership. Because Docker often creates named volumes as root, post-create
runs a `fix_ownership` pass that `chown`s the agent/gh/cache dirs back to the
dev user.

## 4. Loopback on the host; bind host configurable, never hardcoded

Two distinct layers, easy to conflate:

- **Host-side publishing.** The app port is published as
  `127.0.0.1:${PORT}:${PORT}` — bound to host loopback, never `0.0.0.0`. So even
  while the container is up, the dev server is reachable from your machine but
  not from the local network.
- **In-container bind address.** For Docker's port forward to reach the server,
  the process *inside the container* must bind `0.0.0.0` — the forward arrives on
  the container's `eth0`, not its loopback, so a server bound to `127.0.0.1`
  inside the container is unreachable from the host.

The trap: hardcoding `0.0.0.0` in the project's committed dev config to satisfy
the second point. That config is shared with the host — so anyone who later runs
the dev server **directly on the host** (outside the container) now binds it to
all interfaces and exposes it on the network. The container shouldn't impose that
regression on host workflows.

The fix is stack-agnostic: the server's bind address comes from an env var
(`BIND_HOST`), **defaulting to `127.0.0.1`** in committed config (safe on the
host). Only the devcontainer's compose sets `BIND_HOST: 0.0.0.0`, so just the
in-container server listens broadly — and even then host exposure stays loopback
because of the `127.0.0.1:` publish prefix. **Never hardcode `0.0.0.0` in
checked-in config.** Per-framework wiring is in `stack-specific.md`.

## 5. Per-worktree isolation + shared toolchain caches

This makes the setup pleasant to use across many git worktrees of the same repo
simultaneously, without port clashes or rebuilding caches per worktree.

`bin/devcontainer`:

- **Derives a Compose project name** from the worktree directory (sanitized to
  valid Compose chars), so each worktree gets its own isolated stack.
- **Auto-picks a free port** starting at the default, skipping ports already
  taken (except one already published by this project), and writes the chosen
  name+port to `.devcontainer/.env` (which Compose auto-loads). That file holds
  machine/worktree-specific values, so it is **gitignored**, not committed — the
  generator adds `/.devcontainer/.env` to the project's `.gitignore`. It stays
  named `.env` (not `.env.local`) because Compose only auto-loads `.env` and
  resolves `COMPOSE_PROJECT_NAME` / `${PORT}` interpolation from it.
- **Uses the `devcontainer` CLI, not raw `docker compose up`** — that's what runs
  `postCreateCommand` and stamps the locator labels `devcontainer exec` needs.
- **Recovers from stale bind mounts.** If a worktree dir is removed and recreated
  on the host (new inode), a container started against the old inode keeps a
  dangling `/workspace` mount but Compose thinks it's up-to-date. The script
  probes `/workspace` from `/` and force-recreates the container if the mount is
  gone.

Volume scoping reflects the same split:

- **Per-project** (scoped to the Compose project name): shell history, agent
  config, gh config, DB data. Each worktree gets its own.
- **External + shared** across all worktrees: the expensive toolchain caches
  (dependency cache, build cache). Named `{{slug}}-<name>-cache` and declared
  `external: true` so Compose won't try to manage their lifecycle. They must be
  created once up front (`docker volume create …`).

### Making git itself work inside a linked worktree

A subtlety that bites every worktree-in-a-container setup: a **linked worktree's
`.git` is not a real git dir — it's a pointer.** The worktree's `.git` file
reads `gitdir: <main-repo>/.git/worktrees/<name>`, pointing into the *main*
repo's `.git`, which lives **outside** the worktree directory. The compose file
bind-mounts only the worktree dir to `/workspace`, so inside the container that
`gitdir:` path doesn't exist — git can't find the object store, refs, or index,
and **every commit/log/status fails.**

The fix is layout-agnostic and needs no specific git version: mount the **git
common dir** (the main repo's `.git`) into the container **at the same absolute
path it has on the host**. Worktree pointers are absolute, so they resolve with
zero rewriting. `bin/devcontainer` also mounts the worktree's own host path at its
real path, so the back-pointer in `.git/worktrees/<name>/gitdir` resolves too —
keeping `git worktree list`/`prune` and auto-gc correct (otherwise auto-gc could
prune the worktree because its recorded path is missing in the container).

`bin/devcontainer` computes both paths (`git rev-parse --git-common-dir` + the
worktree root), writes them to the gitignored `.devcontainer/.env`, and compose
mounts `source == target` for each. For a normal (non-worktree) checkout the two
are inside / equal to the workspace already, so they're harmless self-mounts.

This does **not** widen the security boundary from principle #1. The worktree
already shares the main repo's object store, so the agent could already read all
history; the mount just makes git functional. No host `~/.gitconfig`, SSH agent,
SSH keys, or push credentials are mounted — the agent still cannot push or sign.
A bind-mounted `.git` is owned by the host user (UID-aligned), and the container
git config sets `safe.directory = *` so git doesn't balk at the host-absolute
mount paths.

## What is generic vs. what varies

Generic (copy near-verbatim): the git boundary, the bypassPermissions +
onboarding setup, UID/GID alignment + ownership fix, loopback ports, the whole
`bin/devcontainer` lifecycle, the `.zshrc`, tmux config, and the README's security
narrative.

Stack-specific (filled by interview — see `stack-specific.md`): the base image,
extra system packages, backing services (DB etc.), the bootstrap commands, the
toolchain cache dirs, and the language section of the global gitignore.

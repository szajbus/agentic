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

## 4. Loopback-only ports

The app port is published as `127.0.0.1:${PORT}:${PORT}` — bound to loopback,
never `0.0.0.0`. The dev server is reachable from the host but not from the
network.

## 5. Per-worktree isolation + shared toolchain caches

This makes the setup pleasant to use across many git worktrees of the same repo
simultaneously, without port clashes or rebuilding caches per worktree.

`bin/worktree`:

- **Derives a Compose project name** from the worktree directory (sanitized to
  valid Compose chars), so each worktree gets its own isolated stack.
- **Auto-picks a free port** starting at the default, skipping ports already
  taken (except one already published by this project), and writes the chosen
  name+port to `.devcontainer/.env` (which Compose auto-loads).
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

## What is generic vs. what varies

Generic (copy near-verbatim): the git boundary, the bypassPermissions +
onboarding setup, UID/GID alignment + ownership fix, loopback ports, the whole
`bin/worktree` lifecycle, the `.zshrc`, tmux config, and the README's security
narrative.

Stack-specific (filled by interview — see `stack-specific.md`): the base image,
extra system packages, backing services (DB etc.), the bootstrap commands, the
toolchain cache dirs, and the language section of the global gitignore.

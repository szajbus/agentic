---
name: devcontainer
description: >-
  Generate a reproducible, sandboxed Dev Container (devcontainer.json + Docker
  Compose + Dockerfile + post-create script + a bin/worktree lifecycle helper +
  a README) for a project, following a security-first "git identity in, secrets
  out" model where an unattended coding agent runs in bypassPermissions but has
  no SSH keys, no push credentials, and no host gitconfig — so it can only read
  history and make local unsigned commits, while signing and push stay on the
  host. Use this when the user wants to add a dev container to a repo, sandbox
  an AI coding agent, set up per-worktree isolated containers with shared
  toolchain caches, or asks to "turn my devcontainer setup into something
  reusable". Stack-agnostic: the reusable core is fixed; base image, extra
  services (DB etc.), bootstrap commands, system packages, and the language
  gitignore are filled in per project via a short interview.
---

# Devcontainer generator

Generate a sandboxed, reproducible Dev Container for a project. The output is a
`.devcontainer/` folder, a `bin/worktree` lifecycle helper, and a README — built
around a deliberate security boundary so an unattended coding agent (Claude Code
in `bypassPermissions`) is safe to run.

This skill encodes a specific philosophy. **Read `references/principles.md`
before generating anything** — the value is in *why* the pieces fit together, not
just the files. The stack-specific details (base image, database, bootstrap)
vary per project and are gathered by interview; `references/stack-specific.md`
catalogs exactly what varies and how to fill it.

## The non-negotiable core (do not let the interview erode these)

These invariants are the whole point. They are the same for every project:

1. **Git: identity in, secrets out.** No SSH agent, no SSH keys, no host
   `~/.gitconfig`, no push/pull credentials in the container. Git inside the
   container is pointed at a self-contained `~/.gitconfig.local` via
   `GIT_CONFIG_GLOBAL`. Commit *identity* is set per-repo with `git config
   --local` (lands in the bind-mounted `.git/config`, shared with the host).
   The container can only **read history and make local, unsigned commits**;
   **fetch/pull/push and commit signing happen on the host.**
2. **Agent runs in `bypassPermissions`, bounded by #1.** The two reinforce each
   other: the agent runs with no approval prompts *because* the git boundary
   caps the blast radius of a runaway or compromised agent.
3. **Non-root user, host UID/GID aligned** (`remoteUser` + `updateRemoteUserUID`,
   plus an ownership fix on mounted volumes in post-create).
4. **Loopback-only port exposure** (`127.0.0.1:...`) — never expose the app port
   on all interfaces.
5. **Per-worktree isolation with shared toolchain caches.** `bin/worktree`
   derives a Compose project name from the worktree directory, auto-picks a free
   port, and recovers from stale bind mounts. Per-project volumes (history, DB,
   agent config) are scoped to the worktree; expensive toolchain caches (deps,
   build artifacts) are *external* volumes shared across worktrees.

If the user wants to drop one of these, that's their call — but flag it
explicitly as weakening the security model, don't silently comply.

## Workflow

### 1. Inspect the target project

Default target is the current repo (or a path the user gives). Determine:

- Is it a git repo? (`bin/worktree` and the identity model assume git.)
- Language / runtime and how deps + builds work (look for `mix.exs`,
  `package.json`, `pyproject.toml`/`requirements.txt`, `go.mod`, `Gemfile`,
  `Cargo.toml`, etc.).
- Does it need a database or other backing service? (Look for Ecto/ActiveRecord/
  Prisma config, a `DATABASE_URL`, docker-compose hints.)
- A sensible project slug (lowercase, `[a-z0-9-]`) and display name.

### 2. Interview (only what you couldn't infer)

Keep it short. Confirm inferred values rather than asking open-endedly. Cover:

- **Project name + slug** (slug is used in volume names, DB name, container name).
- **Base image** — the toolchain image, ideally pinned by digest. See
  `references/stack-specific.md` for per-language suggestions.
- **Backing services** — a database? which engine/version? Anything else
  (redis, etc.)? If none, drop the `db` service entirely.
- **Bootstrap commands** — what `post_install.sh` should run on first create to
  get a working checkout (fetch deps, create/migrate DB, etc.).
- **System packages** — extra apt packages the runtime needs (e.g.
  `inotify-tools`, `postgresql-client`, `build-essential`).
- **Toolchain cache dirs** — which dirs are worth sharing across worktrees as
  external volumes (e.g. `~/.hex` + `~/.mix`, `~/.npm`, `~/.cargo`). These
  become `{{slug}}-<name>-cache` external volumes.
- **Default port** for the app (default 4400 if unknown).
- **Optional**: install any Claude Code plugins/marketplaces at build time?

### 3. Generate the files

Copy the templates from `assets/` into the target, substituting placeholders.
Every placeholder is `{{UPPER_SNAKE}}`. The full list and what each means is in
`references/placeholders.md`. Stack-specific *blocks* (not just scalars) are
marked in the templates with `# >>> STACK:<name>` / `# <<< STACK:<name>`
fences — replace the whole fenced region with what the interview produced, or
delete it if not applicable (e.g. no DB → remove the `db` service block, the
`depends_on`, the DB env vars, and the DB-wait in bootstrap).

Files to generate:

- `.devcontainer/devcontainer.json`
- `.devcontainer/docker-compose.yml`
- `.devcontainer/Dockerfile`
- `.devcontainer/post_install.sh` (chmod +x)
- `.devcontainer/.zshrc`
- `.devcontainer/README.md`
- `bin/worktree` (chmod +x)

After writing: do a final grep for any leftover `{{` placeholder or `STACK:`
fence and resolve it. Don't leave a template token in generated output. (One
expected exception: `bin/worktree` contains Docker's own `{{.Names}}`
Go-template literal — leave it as-is; it is not a skill placeholder.)

### 4. Tell the user the one-time setup

- Create the external cache volumes (otherwise `compose up` fails with
  "volume … could not be found"):
  `docker volume create {{slug}}-<name>-cache` for each cache.
- Set commit identity once per clone:
  `git config --local user.name "…"` and `git config --local user.email "…"`.
- Bring it up: `bin/worktree up` (needs the `devcontainer` CLI:
  `npm i -g @devcontainers/cli`).

Point them at the generated `.devcontainer/README.md` for the rest, especially
the **Git: identity in, secrets out** section.

## Notes

- Don't invent a stack profile you're unsure about — ask. A wrong base image or
  missing bootstrap step makes the container fail on first create, which is a
  bad first impression.
- The `bin/worktree` logic (name sanitizing, free-port picking, stale-mount
  recovery) is generic — only the shared cache volume names and default port are
  project-specific. Keep the logic intact.
- This setup is editor-neutral (it follows the containers.dev spec, not VS Code
  specifics). Don't add VS Code-only keys unless asked.

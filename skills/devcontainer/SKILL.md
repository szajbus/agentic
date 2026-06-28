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
4. **Loopback on the host; bind host configurable, never hardcoded.** Publish the
   app port as `127.0.0.1:...` (host loopback only). The in-container server must
   bind `0.0.0.0` for the forward to work — but supply that via an env var
   (`BIND_HOST`, default `127.0.0.1` in the project's committed config, set to
   `0.0.0.0` only in compose). **Never** hardcode `0.0.0.0` in the project's
   checked-in config — that would expose servers run directly on the host. See
   `references/stack-specific.md` for per-framework wiring.
5. **Per-worktree isolation with shared toolchain caches.** `bin/worktree`
   derives a Compose project name from the worktree directory, auto-picks a free
   port, and recovers from stale bind mounts. Per-project volumes (history, DB,
   agent config) are scoped to the worktree; expensive toolchain caches (deps,
   build artifacts) are *external* volumes shared across worktrees. For **linked
   git worktrees**, it also mounts the git common dir (the main repo's `.git`)
   and the worktree's host path at their real absolute paths, so git actually
   works in the container — a worktree's `.git` is only a pointer into the main
   repo's `.git`, which is otherwise outside the `/workspace` bind. See
   `references/principles.md` → "Making git itself work inside a linked
   worktree". Keep this intact; it's the difference between commits working and
   failing.

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
- **Optional**: does the agent need to drive a **headless browser on the host**
  (e.g. to screenshot / visually check the dev app)? Off by default. If yes, keep
  the `STACK:browser` compose block, the `bin/chrome-host` + `bin/chrome-cdp`
  helpers, and the `websocat` install in the Dockerfile (a no-Node CDP client),
  and read `references/host-browser.md` — it opens a dev-only host control
  channel, so flag the exposure to the user. If no, delete that block, both
  scripts, and the `websocat` Dockerfile step.

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
- `bin/chrome-host`, `bin/chrome-cdp` (chmod +x) — **only if** the host-browser
  feature is enabled; otherwise skip them and delete the `STACK:browser` compose
  block. See `references/host-browser.md`.

Also ensure the **target project's `.gitignore`** ignores the per-worktree env
file `bin/worktree` generates:

```
/.devcontainer/.env
```

Append it if missing (create `.gitignore` if the project has none). This file
holds machine/worktree-specific values (`COMPOSE_PROJECT_NAME`, `PORT`) and must
not be committed. Keep it named `.env` (not `.env.local`): Docker Compose
**auto-loads only `.env`** from the compose project directory and resolves the
interpolation vars `COMPOSE_PROJECT_NAME` / `${PORT}` from it. `.env.local` is not
a Compose convention, and a service `env_file:` cannot supply interpolation vars —
so `.env` + gitignore is the correct mechanism, not a rename.

After writing: do a final grep for any leftover `{{` placeholder or `STACK:`
fence and resolve it. Don't leave a template token in generated output. (One
expected exception: `bin/worktree` contains Docker's own `{{.Names}}`
Go-template literal — leave it as-is; it is not a skill placeholder.)

### 4. Wire the app's bind host (only if the server must be reachable from the host)

If the project runs a server you'll hit from the host (web app, API, dev server),
it must bind `0.0.0.0` *inside the container* — but do that **without** hardcoding
`0.0.0.0` in the project's committed config. Make the smallest possible edit to
the project's own dev config so the bind address reads from `BIND_HOST`,
**defaulting to `127.0.0.1`**. Compose already sets `BIND_HOST: 0.0.0.0` for the
container. This keeps a host-run server on loopback while letting the in-container
server be reachable. Per-framework snippets (Phoenix, Node, Python, Rails, Go) are
in `references/stack-specific.md` → "Making the app reachable from the host".

This is the one place the skill edits files *outside* `.devcontainer/`. Keep it
minimal and call it out to the user. Skip entirely for projects with no
host-facing server (libraries, CLIs).

### 5. Wire the worktree workflow (if the project uses one)

`bin/worktree` is designed to be driven by a worktree workflow — one container
stack per git worktree. The integration is **manager-agnostic**: any tool (or a
plain `git worktree` script) wires in through two hooks. Read
`references/worktree-workflow.md` for the full pattern and rules; the essence:

- **On worktree create:** `bin/worktree up --name <stable-handle>` — pin the
  Compose project name to the worktree's handle so `up`/`exec`/`down` all target
  one stack, bring the container up, and write `.env` (incl. the git-mount paths
  that make in-container commits work). Then exec the agent in with
  `devcontainer exec` (its `--workspace-folder` defaults to cwd = the worktree).
- **On worktree remove (pre-remove, before the dir is deleted):**
  `bin/worktree down` — tear down that worktree's stack + per-project volumes,
  preserving the shared caches. **Never `--caches` here** (siblings share them).

If the project already has a worktree manager configured (e.g. a `.workmux.yaml`,
or a custom script), **offer to wire these hooks into it**, using the example in
`references/worktree-workflow.md`. Don't lock the skill to any one manager —
workmux is just the worked example.

### 6. Tell the user the one-time setup + lifecycle

- Create the external cache volumes (otherwise `compose up` fails with
  "volume … could not be found"):
  `docker volume create {{slug}}-<name>-cache` for each cache.
- Set commit identity once per clone:
  `git config --local user.name "…"` and `git config --local user.email "…"`.
- Bring it up: `bin/worktree up` (needs the `devcontainer` CLI:
  `npm i -g @devcontainers/cli`).

Also give them the day-to-day lifecycle in one breath:

- `bin/worktree up` — (re)build + start this worktree's stack and run post-create.
- `bin/worktree status` — show stack status.
- `bin/worktree down` — remove this worktree's containers + per-project volumes
  (shared caches kept); run it before deleting the worktree dir.
- `bin/worktree down --caches` — same, but also drop the shared caches (only when
  you're done with the whole project).
- Open a shell / run the app: `devcontainer exec zsh`.

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

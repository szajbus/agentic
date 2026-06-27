# Wiring `bin/worktree` into a git-worktree workflow

`bin/worktree` gives **one container stack per git worktree** — isolated
containers/ports/volumes per worktree, with shared toolchain caches. It's built
to be driven by whatever creates and destroys your worktrees: a manager like
workmux, or a hand-rolled `git worktree` script. The integration is the same
two-hook shape regardless of manager. workmux is used here only as a concrete
example — **don't lock the design to it.**

## The pattern: two hooks

1. **On worktree create** — bring the stack up, then exec the agent in:
   ```sh
   bin/worktree up --name <stable-handle>
   devcontainer exec zsh            # or: devcontainer exec <agent>
   ```
2. **On worktree remove** — tear the stack down *before* the directory is deleted:
   ```sh
   bin/worktree down
   ```

## Rules any integrator must follow

These are what make the difference between "it works" and subtle breakage:

- **Pass a stable `--name`.** Use the worktree/branch handle (e.g. the manager's
  `$WM_HANDLE`). It becomes `COMPOSE_PROJECT_NAME` (written to
  `.devcontainer/.env`), so `up`, `devcontainer exec`, and `down` all agree on
  one stack. Without it, a manager that runs its own `devcontainer up` and
  `bin/worktree` can end up driving two differently-named stacks for the same
  worktree.
- **Run `up` before you exec the agent.** Bring the stack up in a *blocking*
  create hook, not in a pane/command that races `devcontainer exec`. The exec
  must land in the already-running, correctly-named stack.
- **Run `down` in a pre-remove hook**, while the worktree directory (and this
  script) still exist — the manager deletes the dir afterwards. `down` removes
  the worktree's containers, network, and per-project volumes and deletes
  `.devcontainer/.env`; shared caches are preserved.
- **Never use `down --caches` in a per-worktree remove hook.** Sibling worktrees
  share those external caches; `--caches` is for whole-project teardown only.
- **Make it non-fatal:** `bin/worktree down || true` so a teardown hiccup never
  blocks the manager's remove.
- **Exec via `devcontainer exec`**, whose `--workspace-folder` defaults to the
  current directory. With the hook's cwd at the worktree root, it execs into
  that worktree's own stack.
- **Copy, don't symlink, files the container must read.** The container
  bind-mounts only the worktree root (`..` → `/workspace`). A file the manager
  *symlinks* back into the main repo dangles inside the container
  (`/workspace/.env.local` → missing). Copy real files (`.env.local`,
  `.claude/settings.local.json`, …) into the worktree instead.

## Example A — plain `git worktree` (no manager)

```sh
# create
git worktree add ../app-feature feature
cd ../app-feature
bin/worktree up --name app-feature      # pins the stack name; commits work in-container
devcontainer exec zsh                    # work inside the container

# ... commit inside the container; sign + push on the host ...

# remove (run down FIRST — bin/worktree lives in the worktree)
bin/worktree down
cd -
git worktree remove ../app-feature
```

You can wrap the create/remove halves in two tiny scripts (`wt-new`, `wt-rm`) if
you do this often.

## Example B — workmux (`.workmux.yaml`)

workmux exposes `post_create` (blocking, before the tmux window opens) and
`pre_remove` (before the worktree is deleted) hooks, plus an `agent` indirection
and file `copy` rules. A complete wiring:

```yaml
# Bring the stack up before the agent pane opens. --name "$WM_HANDLE" pins
# COMPOSE_PROJECT_NAME so up/exec/down share one stack. Blocking (not a pane),
# so it can't race the devcontainer exec below.
post_create:
  - bin/worktree up --name "$WM_HANDLE"

# Tear the stack + per-project volumes down when the worktree is removed.
# Shared caches are KEPT — do NOT add --caches (siblings use them). pre_remove
# runs while the worktree still exists, so the script is still there. || true
# so a hiccup never blocks `workmux rm`.
pre_remove:
  - bin/worktree down || true

# Run the agent INSIDE the container. As the `agent` (not a raw pane command)
# so workmux's <agent> substitution and prompt-injection target it. exec's
# --workspace-folder defaults to the pane cwd (the worktree) → its own stack.
agent: devcontainer exec claude

panes:
  - command: <agent>
    focus: true
  - split: horizontal
    command: devcontainer exec iex -S mix phx.server   # adjust to your stack

# Copy (never symlink) anything the container must read — symlinks into the
# main repo dangle inside /workspace.
files:
  copy:
    - .env.local
    - .claude/settings.local.json
```

The same two ideas (`up --name <handle>` on create, `down` on pre-remove) map
onto any other manager's equivalent hooks.

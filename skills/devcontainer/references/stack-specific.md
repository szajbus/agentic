# Stack-specific parts — what varies per project, and how to fill it

The reusable core is fixed. These pieces change per language/stack and are
gathered during the interview, then substituted into the templates. Below is
what each one is, where it lives in the templates, and starting points for
common stacks. The Elixir/Phoenix column is the original reference setup this
skill was extracted from.

## The variable pieces

| Piece | Lives in | Placeholder / fence |
|---|---|---|
| Base toolchain image (pin by digest) | `Dockerfile` | `{{BASE_IMAGE}}` |
| Extra system packages | `Dockerfile` | `STACK:packages` fence |
| Backing service(s) (DB etc.) | `docker-compose.yml` | `STACK:services` fence + `STACK:depends_on` + `STACK:db_env` |
| Toolchain cache volumes | `docker-compose.yml` | `STACK:cache_volumes` fence |
| Cache mount points | `docker-compose.yml` | `STACK:cache_mounts` fence |
| Bootstrap (deps, DB create/migrate) | `post_install.sh` | `STACK:bootstrap` fence |
| Language gitignore entries | `post_install.sh` | `STACK:gitignore` fence |
| Optional agent plugins at build | `Dockerfile` | `STACK:plugins` fence |
| Optional agent plugins at post-create | `post_install.sh` | `STACK:plugins` fence |
| Cache dirs to fix ownership on | `post_install.sh` | `{{CACHE_OWNERSHIP_DIRS}}` |

Scalars used everywhere: `{{PROJECT_NAME}}`, `{{PROJECT_SLUG}}`, `{{DEFAULT_PORT}}`.
See `placeholders.md` for the complete list.

## Reference: Elixir / Phoenix (the original)

- **Base image**: `hexpm/elixir:1.20.0-erlang-28.5-debian-bookworm-…-slim`,
  pinned by digest.
- **System packages**: `inotify-tools` (file watching), `postgresql-client`
  (psql + pg_isready), `build-essential` (native deps), plus the generic dev
  tooling that's already in the core list.
- **Service**: `postgres:16-alpine`, DB `{{slug}}_dev`, reached at host `db`;
  app gets `DATABASE_HOST=db`, `POSTGRES_USER/PASSWORD`.
- **Caches**: `~/.hex` and `~/.mix` → external volumes `{{slug}}-hex-cache`,
  `{{slug}}-mix-cache`.
- **Bootstrap**: `mix local.hex --force`, `mix local.rebar --force`, then if
  `mix.exs` exists: `mix deps.get`, wait for Postgres via `pg_isready`,
  `mix ecto.create`, `mix ecto.migrate`.
- **Gitignore**: `/_build/`, `/deps/`, `/cover/`, `/.elixir_ls/`,
  `erl_crash.dump`.
- **Plugins (optional)**: an `elixir-phoenix` Claude Code marketplace plugin.

## Starting points for other stacks

These are suggestions to confirm with the user, not gospel. Always prefer
pinning the base image by digest.

### Node / TypeScript

- Base: `node:22-bookworm-slim` (or `-bookworm` if native builds needed).
- Packages: usually none beyond the core; add `build-essential` for native
  modules.
- Caches: `~/.npm` (or pnpm store `~/.local/share/pnpm`, or `~/.yarn`) →
  `{{slug}}-npm-cache`.
- Bootstrap: `npm ci` (or `pnpm install --frozen-lockfile`); run migrations /
  `prisma migrate dev` if applicable.
- Gitignore: `/node_modules/`, `/dist/`, `/.next/`, `*.tsbuildinfo`.
- DB: commonly Postgres; same `db` service as the Elixir reference.

### Python

- Base: `python:3.13-bookworm-slim`.
- Packages: `build-essential`, `libpq-dev` if using psycopg.
- Caches: `~/.cache/pip` (or the uv cache `~/.cache/uv`) → `{{slug}}-pip-cache`.
- Bootstrap: `pip install -r requirements.txt` / `uv sync` / `poetry install`;
  `alembic upgrade head` or `manage.py migrate` if applicable.
- Gitignore: `__pycache__/`, `*.pyc`, `.venv/`, `.pytest_cache/`, `.mypy_cache/`.

### Go

- Base: `golang:1.23-bookworm`.
- Caches: `~/.cache/go-build` and `~/go/pkg/mod` → `{{slug}}-go-build-cache`,
  `{{slug}}-go-mod-cache`.
- Bootstrap: `go mod download`; `go build ./...`.
- Gitignore: `/bin/`, `*.test`, `*.out`.

### Ruby / Rails

- Base: `ruby:3.3-bookworm`.
- Packages: `build-essential`, `libpq-dev`, `libyaml-dev`.
- Caches: the bundle dir (set `BUNDLE_PATH=~/.bundle`) → `{{slug}}-bundle-cache`.
- Bootstrap: `bundle install`; `bin/rails db:prepare`.
- Gitignore: `/tmp/`, `/log/`, `*.gem`.

## Deciding what to cache

A dir is worth making a shared external cache when (a) it's expensive to
repopulate (network fetch + compile), and (b) it's safe to share across
worktrees of the same project (content-addressed or version-keyed, not
worktree-specific state). Dependency download caches and compiler caches
qualify. Built artifacts that are checkout-specific (`_build/`, `dist/`,
`node_modules/` symlinked into the tree) generally do **not** — keep those
per-project or in the workspace.

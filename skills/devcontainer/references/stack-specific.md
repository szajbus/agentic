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

## Making the app reachable from the host (bind host)

If the project serves something you'll open from the host, the in-container
server must bind `0.0.0.0` (Docker's port forward lands on the container's
`eth0`, not loopback). But **don't hardcode `0.0.0.0` in committed config** — it
would expose a server someone later runs directly on the host. Instead read the
bind address from `BIND_HOST`, defaulting to `127.0.0.1`. Compose already exports
`BIND_HOST: 0.0.0.0` for the container. Make the smallest edit that does this in
the project's *own* dev config. Pair it with reading `PORT` (compose sets that
too) so the published port matches.

### Elixir / Phoenix — `config/dev.exs`

Phoenix's `:ip` option wants an address tuple, so parse the env var:

```elixir
bind_ip =
  "BIND_HOST"
  |> System.get_env("127.0.0.1")
  |> String.to_charlist()
  |> :inet.parse_address()
  |> case do
    {:ok, ip} -> ip
    _ -> {127, 0, 0, 1}
  end

config :my_app, MyAppWeb.Endpoint,
  http: [ip: bind_ip, port: String.to_integer(System.get_env("PORT") || "4000")],
  # ...rest unchanged
```

This replaces the default hardcoded `ip: {127, 0, 0, 1}` — note the default is
still loopback, so `mix phx.server` on the host is unchanged.

### Node — server / Vite / Next

```js
const host = process.env.BIND_HOST || "127.0.0.1";
const port = process.env.PORT || 3000;
app.listen(port, host);                       // Express/http
// Vite:  server: { host: process.env.BIND_HOST || "127.0.0.1" }
// Next:  next dev -H ${BIND_HOST:-127.0.0.1} -p ${PORT:-3000}
```

### Python — Django / Flask / uvicorn

```sh
# Django (in a run script / bootstrap):
python manage.py runserver "${BIND_HOST:-127.0.0.1}:${PORT:-8000}"
# uvicorn:
uvicorn app:app --host "${BIND_HOST:-127.0.0.1}" --port "${PORT:-8000}"
```
```python
# Flask:
app.run(host=os.environ.get("BIND_HOST", "127.0.0.1"),
        port=int(os.environ.get("PORT", "5000")))
```

### Ruby / Rails

```sh
bin/rails server -b "${BIND_HOST:-127.0.0.1}" -p "${PORT:-3000}"
```

### Go

```go
host := os.Getenv("BIND_HOST")
if host == "" { host = "127.0.0.1" }
port := os.Getenv("PORT")
if port == "" { port = "8080" }
http.ListenAndServe(net.JoinHostPort(host, port), mux)
```

If a framework only accepts the bind host as a CLI flag (Rails, Django, Vite),
put the `${BIND_HOST:-127.0.0.1}` form in how the server is launched rather than
editing source — same effect, no committed `0.0.0.0`.

## Deciding what to cache

A dir is worth making a shared external cache when (a) it's expensive to
repopulate (network fetch + compile), and (b) it's safe to share across
worktrees of the same project (content-addressed or version-keyed, not
worktree-specific state). Dependency download caches and compiler caches
qualify. Built artifacts that are checkout-specific (`_build/`, `dist/`,
`node_modules/` symlinked into the tree) generally do **not** — keep those
per-project or in the workspace.

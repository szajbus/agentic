# Placeholder & fence reference

Every template token is `{{UPPER_SNAKE}}`. Stack-specific *blocks* are wrapped in
fence comments so you can replace or delete a whole region cleanly.

## Scalar placeholders

| Placeholder | Meaning | Example |
|---|---|---|
| `{{PROJECT_NAME}}` | Human display name | `Tix` |
| `{{PROJECT_SLUG}}` | lowercase `[a-z0-9-]`; used in DB name, container name, volume names | `tix` |
| `{{DEFAULT_PORT}}` | Default app port (loopback) | `4400` |
| `{{BASE_IMAGE}}` | Toolchain base image, ideally digest-pinned (full `FROM` target) | `hexpm/elixir:1.20.0-erlang-28.5-debian-bookworm-20260610-slim@sha256:…` |
| `{{CACHE_OWNERSHIP_DIRS}}` | Space-separated cache dirs for the ownership fix | `"$HOME/.hex" "$HOME/.mix"` |
| `{{SHARED_VOLUMES}}` | Space-separated external cache volume names, in `bin/worktree` | `tix-hex-cache tix-mix-cache` |

> **Caveat — `{{.Names}}` in `bin/worktree` is NOT a placeholder.** It is a
> Docker Go-template literal (`docker ps --format '{{.Names}}'`). Leave it
> exactly as-is. When you run the final `{{`-grep check, expect that one line in
> `bin/worktree` to match, and ignore it. Everything else matching `{{` is a
> real placeholder to resolve.

## Fenced stack blocks

Each appears as a pair of comment lines in the template. Replace everything
between them (inclusive of the fence lines) with the generated content, or
delete the whole region if not applicable.

```
# >>> STACK:packages
…apt packages here…
# <<< STACK:packages
```

| Fence | File | Replace with / delete when |
|---|---|---|
| `STACK:packages` | `Dockerfile` | extra apt packages; keep core list |
| `STACK:plugins` | `Dockerfile` | agent marketplace/plugin installs at build time; delete if none |
| `STACK:services` | `docker-compose.yml` | the `db:` (and other) service block; delete if no backing service |
| `STACK:depends_on` | `docker-compose.yml` | the app's `depends_on`; delete if no services |
| `STACK:db_env` | `docker-compose.yml` | app env vars pointing at the DB; delete if no DB |
| `STACK:db_volume` | `docker-compose.yml` | the `db-data:` per-project volume decl; delete if no DB |
| `STACK:browser` | `docker-compose.yml` | `extra_hosts` for host-browser access; delete (and skip `bin/chrome-*`) if the agent doesn't drive a host browser. See `host-browser.md` |
| `STACK:cache_mounts` | `docker-compose.yml` | the app's cache volume mount lines |
| `STACK:cache_volumes` | `docker-compose.yml` | the external cache volume declarations |
| `STACK:bootstrap` | `post_install.sh` | the bootstrap function body (deps, DB create/migrate) |
| `STACK:gitignore` | `post_install.sh` | language-specific gitignore entries |
| `STACK:plugins` | `post_install.sh` | agent plugin install at post-create; delete if none |

## Per-cache substitution

For each shared toolchain cache the interview identified, you generate three
things that must agree on the same name `{{PROJECT_SLUG}}-<cachename>-cache`:

1. a mount under the app service (`STACK:cache_mounts`),
2. an `external: true` declaration (`STACK:cache_volumes`),
3. an entry in `{{CACHE_OWNERSHIP_DIRS}}` and in the README's prerequisites.

## Final check

After substitution, grep the generated tree for `{{` and `STACK:` — there
should be zero matches. A leftover fence or token means an unfinished region.

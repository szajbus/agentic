#!/usr/bin/env bash
# Post-create setup for the {{PROJECT_NAME}} devcontainer.
# Runs once after the container is created (see devcontainer.json postCreateCommand).
set -euo pipefail

log() { printf '[post_install] %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Fix ownership on mounted volumes (Docker often creates these as root).
# ---------------------------------------------------------------------------
fix_ownership() {
  local uid gid
  uid=$(id -u)
  gid=$(id -g)
  for dir in "$HOME/.claude" "$HOME/.config/gh" {{CACHE_OWNERSHIP_DIRS}} /commandhistory; do
    if [[ -d "$dir" ]] && [[ "$(stat -c %u "$dir")" != "$uid" ]]; then
      sudo chown -R "$uid:$gid" "$dir"
      log "Fixed ownership: $dir"
    fi
  done
}

# ---------------------------------------------------------------------------
# Claude Code: skip onboarding when a token is forwarded from the host.
# `claude -p` seeds ~/.claude.json with auth state; we then flip the flag.
# ---------------------------------------------------------------------------
setup_claude_onboarding() {
  if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    log "CLAUDE_CODE_OAUTH_TOKEN not set, skipping onboarding bypass"
    return
  fi

  local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME}"
  local claude_json="$claude_dir/.claude.json"

  log "Seeding Claude auth state via 'claude -p'..."
  timeout 30 claude -p ok >/dev/null 2>&1 || true

  if [[ ! -f "$claude_json" ]]; then
    log "Warning: $claude_json not created — onboarding bypass skipped"
    return
  fi

  # Flip hasCompletedOnboarding to true (jq is installed in the image).
  local tmp
  tmp=$(mktemp)
  jq '.hasCompletedOnboarding = true' "$claude_json" > "$tmp" && mv "$tmp" "$claude_json"
  log "Onboarding bypass configured: $claude_json"
}

# ---------------------------------------------------------------------------
# Claude Code: bypassPermissions default mode.
# ---------------------------------------------------------------------------
setup_claude_settings() {
  local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  mkdir -p "$claude_dir"
  local settings="$claude_dir/settings.json"

  if [[ -s "$settings" ]]; then
    local tmp
    tmp=$(mktemp)
    jq '.permissions.defaultMode = "bypassPermissions"' "$settings" > "$tmp" && mv "$tmp" "$settings"
  else
    printf '%s\n' '{"permissions":{"defaultMode":"bypassPermissions"}}' | jq '.' > "$settings"
  fi
  log "Claude settings configured: $settings"
}

# ---------------------------------------------------------------------------
# Claude Code: optional project-scoped plugins.
# ---------------------------------------------------------------------------
setup_plugins() {
# >>> STACK:plugins
  # Optional: install project-scoped Claude Code plugins, e.g.
  #
  #   local marketplace_repo="oliver-kriska/claude-elixir-phoenix"
  #   local plugin="elixir-phoenix@oliver-kriska"
  #   claude plugin marketplace add "$marketplace_repo" --scope project >/dev/null 2>&1 || true
  #   if claude plugin install "$plugin" --scope project >/dev/null 2>&1; then
  #     log "Installed plugin: $plugin (project scope)"
  #   else
  #     log "Warning: failed to install plugin $plugin (already installed?)"
  #   fi
  #
  # Delete this function (and its call in main) if no plugins are needed.
  :
# <<< STACK:plugins
}

# ---------------------------------------------------------------------------
# Tmux config (only if user hasn't supplied one).
# ---------------------------------------------------------------------------
setup_tmux() {
  local conf="$HOME/.tmux.conf"
  if [[ -e "$conf" ]]; then
    log "Tmux config exists, skipping"
    return
  fi
  cat > "$conf" <<'TMUX'
set-option -g history-limit 200000
set -g mouse on
setw -g mode-keys vi
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -sg escape-time 10
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -as terminal-features ",xterm-ghostty:RGB"
set -as terminal-features ",xterm*:RGB"
set -ga terminal-overrides ",xterm*:colors=256"
set -ga terminal-overrides '*:Ss=\E[%p1%d q:Se=\E[ q'
set -g status-style 'bg=#333333 fg=#ffffff'
set -g status-left '[#S] '
set -g status-right '%Y-%m-%d %H:%M'
TMUX
  log "Tmux configured: $conf"
}

# ---------------------------------------------------------------------------
# Git: self-contained container-local config (no host gitconfig is mounted)
# with container-only settings (excludesfile, delta, merge style). Commit
# identity is set per-repo via `git config --local` (see .devcontainer/README).
# GIT_CONFIG_GLOBAL points git at this file.
# ---------------------------------------------------------------------------
setup_git() {
  local gitignore="$HOME/.gitignore_global"
  local local_gitconfig="$HOME/.gitconfig.local"

  cat > "$gitignore" <<'GI'
# Claude Code
.claude/

# macOS
.DS_Store
._*

# Editors
*.swp
*.swo
*~
.idea/
.vscode/

# >>> STACK:gitignore
# Language/build-specific ignores, e.g. (Elixir): /_build/ /deps/ /cover/
# <<< STACK:gitignore

# Misc
*.log
.env.local
.env.*.local
GI
  log "Global gitignore created: $gitignore"

  cat > "$local_gitconfig" <<GC
# Container-local git config. Self-contained — no host .gitconfig is mounted.
# GIT_CONFIG_GLOBAL points git here. Commit identity is set per-repo with
# 'git config --local'.

[core]
    excludesfile = ${gitignore}
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    light = false
    line-numbers = true
    side-by-side = false

[merge]
    conflictstyle = diff3

[diff]
    colorMoved = default
GC
  log "Container git config created: $local_gitconfig"
  # Commit identity is NOT set here — it's configured per-repo with
  # 'git config --local' (stored in the bind-mounted .git/config, shared with
  # the host). If unset, commits fail loudly until you set it. See README.
}

# ---------------------------------------------------------------------------
# Toolchain bootstrap: fetch deps, prepare the database, etc.
# Idempotent — runs on every (re)create.
# ---------------------------------------------------------------------------
setup_bootstrap() {
# >>> STACK:bootstrap
  # Stack-specific bootstrap. Example (Elixir/Phoenix):
  #
  #   mix local.hex --force >/dev/null
  #   mix local.rebar --force >/dev/null
  #   if [[ -f mix.exs ]]; then
  #     mix deps.get
  #     log "Waiting for Postgres at ${DATABASE_HOST:-db}:5432..."
  #     until pg_isready -h "${DATABASE_HOST:-db}" -U "${POSTGRES_USER:-postgres}" >/dev/null 2>&1; do
  #       sleep 1
  #     done
  #     mix ecto.create
  #     mix ecto.migrate
  #   fi
  #
  # Replace with the bootstrap for this project's stack.
  log "No bootstrap configured"
# <<< STACK:bootstrap
}

main() {
  log "Starting post-create setup..."
  fix_ownership
  setup_claude_onboarding
  setup_claude_settings
  setup_plugins
  setup_tmux
  setup_git
  setup_bootstrap
  log "Done."
}

main "$@"

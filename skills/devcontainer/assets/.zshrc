# shellcheck shell=bash
# {{PROJECT_NAME}} devcontainer zsh configuration

export PATH="$HOME/.local/bin:$PATH"

# History — persisted to /commandhistory volume so it survives rebuilds.
export HISTFILE=/commandhistory/.zsh_history
export HISTSIZE=200000
export SAVEHIST=200000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END

alias fd=fdfind
alias claude-yolo='claude --dangerously-skip-permissions'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'

# fzf with fd as the source
export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fdfind --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'

_fzf_compgen_path() {
  fdfind --hidden --follow --exclude .git . "$1"
}
_fzf_compgen_dir() {
  fdfind --type d --hidden --follow --exclude .git . "$1"
}

eval "$(fzf --zsh)"

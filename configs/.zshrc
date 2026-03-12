# ── Oh My Zsh ──
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  docker
  fzf
)

fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

source "$ZSH/oh-my-zsh.sh"

# ── nvm ──
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# ── pyenv ──
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv &>/dev/null && eval "$(pyenv init -)"

# ── SDKMAN ──
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

# ── zoxide ──
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# ── fzf ──
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ── Aliases ──
alias ls="eza --icons"
alias ll="eza -la --icons"
alias lt="eza --tree --icons --level=2"
alias cat="bat"
alias g="git"
alias gs="git status"
alias gd="git diff"
alias gl="git log --oneline --graph"
alias gp="git push"
alias gc="git commit"

# ── Local bin ──
export PATH="$HOME/.local/bin:$PATH"

# ── Starship ──
eval "$(starship init zsh)"

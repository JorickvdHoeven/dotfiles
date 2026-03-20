### jorick's zshrc file (starship edition — no heavy plugins)

## This file requires the following to be installed:
#     - brew
#     - fzf
#     - zoxide
#     - fd
#     - direnv
#     - eza
#     - neovim
#     - git
#     - starship (brew install starship)
#     - bat (for previews)
#
## Optional (auto-installed by zsh-update-alt.sh):
#     - zsh-syntax-highlighting (via homebrew)
#     - zsh-autosuggestions (via homebrew)
#     - zsh-completions (via homebrew)

# ── Homebrew (deduplicated) ──
if [[ -f "${HOME}/environment/homebrew/bin/brew" ]]; then
  eval "$(${HOME}/environment/homebrew/bin/brew shellenv)"
elif [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ── Brew prefix (cached to avoid repeated calls) ──
if command -v brew &>/dev/null; then
  BREW_PREFIX="$(brew --prefix)"
fi

# ── Completions (must come before compinit) ──
# zsh-completions from homebrew
if [[ -d "${BREW_PREFIX}/share/zsh-completions" ]]; then
  fpath=("${BREW_PREFIX}/share/zsh-completions" $fpath)
fi

# Completions (cached, regenerated once per day)
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# ── Plugins via Homebrew (lightweight, no git clones) ──

# zsh-autosuggestions
if [[ -f "${BREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "${BREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# zsh-syntax-highlighting (must be sourced last among plugins)
if [[ -f "${BREW_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "${BREW_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

######
## Eza (better ls)
######
alias ls="eza --color=always --icons=always --git"

######
## direnv (local folder env variables)
######
eval "$(direnv hook zsh)"

######
## fzf setup (better completion and search)
######

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --zsh)"

# --- setup fzf theme ---
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

# -- Use fd instead of fzf --
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git --exclude .eden --exclude edenfs --exclude fbsource"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git --exclude .eden --exclude edenfs --exclude fbsource"

# Use fd for listing path candidates.
_fzf_compgen_path() {
  fd --hidden --exclude .git --exclude .eden --exclude edenfs --exclude fbsource . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git --exclude .eden --exclude edenfs --exclude fbsource . "$1"
}

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced customization of fzf options via _fzf_comprun function
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo \${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}

# Keybindings
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[w' kill-region

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu select

# Aliases
alias vim='nvim'
alias vi='nvim'
alias c='clear'
alias config="git --git-dir=$HOME/.dotfiles --work-tree=$HOME"

# ── Machine-specific config ──
[[ ! -f "${HOME}/.machinerc" ]] && touch "${HOME}/.machinerc"
source "${HOME}/.machinerc"

# added by setup_fb4a.sh
export ANDROID_SDK=/opt/android_sdk
export ANDROID_NDK_REPOSITORY=/opt/android_ndk
export ANDROID_HOME=${ANDROID_SDK}
export PATH=${PATH}:${ANDROID_SDK}/emulator:${ANDROID_SDK}/tools:${ANDROID_SDK}/tools/bin:${ANDROID_SDK}/platform-tools
fastboot() { if $(ek status | grep -q '"status": {}'); then /opt/facebook/maui-cli/bin/platform-tools/fastboot "$@"; else /var/folders/c0/z8r_nsr91_1c_l9zgsc85gf40000gn/0/ek/android/fastboot "$@"; fi } # EK_RC_ENV_hRtVBQ556GKN

# ── Zoxide (smart cd) ──
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# ── Starship prompt (fast, cross-shell, customizable) ──
# Configure: ~/.config/starship.toml
eval "$(starship init zsh)"

# ── Background weekly dependency check ──
# Runs zsh-update-alt.sh asynchronously to ensure brew packages are present.
() {
  local stamp="${HOME}/.config/environment/.last_update_alt"
  local now=$(date +%s)
  local interval=$((7 * 24 * 60 * 60))

  [[ ! -f "$stamp" ]] && return

  local last=$(cat "$stamp" 2>/dev/null || echo 0)
  if (( now - last >= interval )); then
    "${HOME}/.config/environment/zsh-update-alt.sh" &>/dev/null &!
  fi
}

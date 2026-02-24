### jorick's zshrc file

## This file requires the following to be installed:
#     - brew
#     - fzf
#     - zoxide
#     - fd
#     - direnv
#     - eza
#     - neovim
#     - git

# ── Powerlevel10k instant prompt (must stay at top) ──
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ── Homebrew (deduplicated) ──
if [[ -f "${HOME}/environment/homebrew/bin/brew" ]]; then
  eval "$(${HOME}/environment/homebrew/bin/brew shellenv)"
elif [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ── Plugin directory ──
ZSH_ENV_DIR="${HOME}/.config/environment"
mkdir -p "${ZSH_ENV_DIR}"

# ── First run: install missing plugins synchronously (one-time cost) ──
if [[ ! -d "${ZSH_ENV_DIR}/powerlevel10k" ]] || \
   [[ ! -d "${ZSH_ENV_DIR}/fzf-tab" ]] || \
   [[ ! -d "${ZSH_ENV_DIR}/zsh-syntax-highlighting" ]] || \
   [[ ! -d "${ZSH_ENV_DIR}/zsh-completions" ]] || \
   [[ ! -d "${ZSH_ENV_DIR}/zsh-autosuggestions" ]]; then
  echo "Installing missing zsh plugins..."
  "${ZSH_ENV_DIR}/zsh-update.sh"
fi

# ── Source plugins (skip silently if missing) ──
[[ -f "${ZSH_ENV_DIR}/powerlevel10k/powerlevel10k.zsh-theme" ]] && \
  source "${ZSH_ENV_DIR}/powerlevel10k/powerlevel10k.zsh-theme"

# zsh-completions must be added to fpath before compinit
[[ -d "${ZSH_ENV_DIR}/zsh-completions/src" ]] && \
  fpath=("${ZSH_ENV_DIR}/zsh-completions/src" $fpath)

# Completions (cached, regenerated once per day instead of every shell)
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# fzf-tab must be loaded after compinit
[[ -f "${ZSH_ENV_DIR}/fzf-tab/fzf-tab.plugin.zsh" ]] && \
  source "${ZSH_ENV_DIR}/fzf-tab/fzf-tab.plugin.zsh"

[[ -f "${ZSH_ENV_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
  source "${ZSH_ENV_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh"

# syntax-highlighting must be sourced last among plugins
[[ -f "${ZSH_ENV_DIR}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \
  source "${ZSH_ENV_DIR}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

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

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
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
# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
# NOTE: don't use escape sequences here, fzf-tab will ignore them
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:(code|vi|nvim|vim|open):*' fzf-preview 'if [ -d $realpath ]; then eza --tree --color=always --level 2 $realpath | head -200; else bat -n --color=always --line-range :500 $realpath; fi'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --color=always --level 2 $realpath | head -200 '
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --tree --color=always $realpath  --level 2| head -200'
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
	fzf-preview 'echo ${(P)word}'
zstyle ':fzf-tab:complete:echo:$*' \
	fzf-preview 'echo ${(P)word}'


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

# ── Background weekly plugin update ──
# Checks if 7+ days have passed since last update, then runs the updater
# asynchronously so the shell isn't blocked.
() {
  local stamp="${ZSH_ENV_DIR}/.last_update"
  local now=$(date +%s)
  local interval=$((7 * 24 * 60 * 60))

  # No stamp file means first run was just handled above
  [[ ! -f "$stamp" ]] && return

  local last=$(cat "$stamp" 2>/dev/null || echo 0)
  if (( now - last >= interval )); then
    "${ZSH_ENV_DIR}/zsh-update.sh" &>/dev/null &!
  fi
}

. "$HOME/.local/bin/env"

# Enable iTerm2 integration
test -e /Users/jorickvdh/.iterm2_shell_integration.zsh && source /Users/jorickvdh/.iterm2_shell_integration.zsh || true

# Add hostname badges in tmux terminals
# if [[ -n "$TMUX" ]]; then
#   printf "\ePtmux;\e\e]1337;SetBadgeFormat=%s\a\e\\" $(echo -n "$HOST" | base64)
#else
#    printf "\e]1337;SetBadgeFormat=%s\a" $(echo -n "$HOST" | base64)
#fi

### jorick's .zshrc file

## This file requires the following to be installed:
#     - brew
#     - fzf
#     - zoxide
#     - fd
#     - direnv
#     - eza
#     - neovim
#     - git

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


if [[ -f "~/environment/homebrew/bin/brew" ]] then
  # This is to enable homebrew in environments where I have to install homebrew as non-admin
  eval "$(~/environment/homebrew/bin/brew shellenv)"
fi

if [[ -f "/opt/homebrew/bin/brew" ]] then
  # This is to enable homebrew in MacOS
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

######
## Set up Pyenv
######
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"


if [[ -f "/opt/homebrew/bin/brew" ]] then
  # This is to enable homebrew in MacOS
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [[ ! -f "${HOME}/.config/environment/powerlevel10k/powerlevel10k.zsh-theme" ]] then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.config/environment/powerlevel10k
fi
source ~/.config/environment/powerlevel10k/powerlevel10k.zsh-theme


if [[ ! -f "${HOME}/.config/environment/powerlevel10k/powerlevel10k.zsh-theme" ]] then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.config/environment/powerlevel10k
fi
source ~/.config/environment/powerlevel10k/powerlevel10k.zsh-theme

if [[ ! -f "${HOME}/.config/environment/fzf-tab/fzf-tab.plugin.zsh" ]] then
  git clone --depth=1 https://github.com/Aloxaf/fzf-tab ~/.config/environment/fzf-tab
fi
# Load completions
autoload -Uz compinit && compinit
source ~/.config/environment/fzf-tab/fzf-tab.plugin.zsh

# Check if zsh-syntax-highlighting is installed
if [[ ! -d "${HOME}/.config/environment/zsh-syntax-highlighting" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${HOME}/.config/environment/zsh-syntax-highlighting"
fi
source "${HOME}/.config/environment/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

if [[ ! -d "${HOME}/.config/environment/zsh-completions" ]] then
  git clone --depth=1 https://github.com/zsh-users/zsh-completions.git "${HOME}/.config/environment/zsh-completions"
fi
 fpath=("${HOME}/.config/environment/zsh-completions/src"  $fpath)

if [[ ! -f "${HOME}/.config/environment/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] then
 git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "${HOME}/.config/environment/zsh-autosuggestions"
fi
source "${HOME}/.config/environment/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Reload completions
autoload -U compinit && compinit

######
## Eza (better ls)
######
alias ls="eza --color=always --icons=always --git"

######
## direnv (local folder env variables)
######
eval "$(direnv hook zsh)"


######
## fzf setup (better completion and search
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
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Aliases
alias vim='nvim'
alias vi='nvim'
alias c='clear'
#####
# Create a config command to stroe config commands
#####
# Creating the Repo
# If you’re setting this up the first time, there’s a few steps 
# you’ll need to take to set up. First, create the repository:
#      git init --bare $HOME/.dotfiles
# This creates a “bare” git repository at ~/.dotfiles. Now we'll 
# set up an alias to interact with it from any directory on disk. 
# Add the following alias to your ~/.bashrc or ~/.zshrc or 
#      ~/.config/fish/config.fish file, then source the file:
# make sure the --git-dir is the same as the
# directory where you created the repo above.
#      alias config="git --git-dir=$HOME/.dotfiles --work-tree=$HOME"
# The --work-tree=$HOME option sets the directory that the repository 
# tracks to your home directory. Now, since there's probably more files 
# in your home directory that you don't want in the repo than files 
# you do want in the repo, you should configure the repo to not 
# show untracked files by default. We can do that by setting a 
# repository-local configuration option.
#     config config --local status.showUntrackedFiles no


alias config="git --git-dir=$HOME/.dotfiles --work-tree=$HOME"

if [[ ! -f "${HOME}/.machinerc" ]] then
  touch "${HOME}/.machinerc" 
fi
source "${HOME}/.machinerc"




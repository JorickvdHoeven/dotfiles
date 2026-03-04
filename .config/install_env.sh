#!/usr/bin/env bash
# ~/.config/install_env.sh
# Full environment bootstrap for the starship-based zsh setup.
# Installs Homebrew (if missing), all brew dependencies, and clones dotfiles.

set -euo pipefail

echo "=== Starship Environment Setup ==="

# ── 1. Clone dotfiles (bare repo) ──
if [[ ! -d "$HOME/.dotfiles" ]]; then
  echo "Cloning dotfiles..."
  git clone --bare git@github.com:jorickvdhoeven/dotfiles.git "$HOME/.dotfiles"
fi

config() {
  git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" "$@"
}

mkdir -p "$HOME/.dotfiles-backup"
if ! config checkout 2>/dev/null; then
  echo "Moving existing dotfiles to ~/.dotfiles-backup"
  config checkout 2>&1 | grep -E "^\s+\." | awk '{print $1}' | xargs -I{} mv {} "$HOME/.dotfiles-backup/{}"
  config checkout
fi
config config status.showUntrackedFiles no
echo "✓ Dotfiles installed"

# ── 2. Install Homebrew ──
if ! command -v brew &>/dev/null; then
  # Also check common non-standard locations
  if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -f "${HOME}/environment/homebrew/bin/brew" ]]; then
    eval "$(${HOME}/environment/homebrew/bin/brew shellenv)"
  else
    # Try git clone first (works behind proxies and without sudo)
    echo "Installing Homebrew to ~/environment/homebrew..."
    mkdir -p "${HOME}/environment"
    if git clone https://github.com/Homebrew/brew.git "${HOME}/environment/homebrew"; then
      eval "$(${HOME}/environment/homebrew/bin/brew shellenv)"
      brew update --force --quiet
    elif sudo -n true 2>/dev/null; then
      # Fallback: system-wide install (requires internet without proxy issues)
      echo "Git clone failed, trying system-wide install..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
    else
      echo "ERROR: Could not install Homebrew. Install it manually and re-run."
      exit 1
    fi
  fi
fi

if ! command -v brew &>/dev/null; then
  echo "ERROR: brew still not found after install. Check your PATH."
  exit 1
fi
echo "✓ Homebrew ready"

# ── 3. Install brew packages ──
brew_packages=(
  # Shell & prompt
  starship

  # Core CLI tools
  fzf
  fd
  eza
  bat
  zoxide
  direnv
  neovim
  git
  git-delta

  # Zsh plugins (via brew, no git clones needed)
  zsh-syntax-highlighting
  zsh-autosuggestions
  zsh-completions
)

echo "Installing brew packages..."
for pkg in "${brew_packages[@]}"; do
  # Check if already available on the system (e.g. git via Xcode CLT)
  bin_name="${pkg}"
  # Map brew package names to binary names where they differ
  case "$pkg" in
    git-delta)  bin_name="delta" ;;
    zsh-*)      bin_name="" ;;  # plugins, no binary to check
  esac

  if [[ -n "$bin_name" ]] && command -v "$bin_name" &>/dev/null && ! brew list "$pkg" &>/dev/null; then
    echo "  $pkg already available (system), skipping"
  elif brew list "$pkg" &>/dev/null; then
    echo "  $pkg already installed (brew)"
  else
    echo "  Installing $pkg..."
    brew install "$pkg"
  fi
done
echo "✓ All packages installed"

# ── 4. Activate .zshrc_alt ──
if [[ -f "$HOME/.zshrc_alt" ]]; then
  echo ""
  echo "To switch to the starship config, run:"
  echo "  cp ~/.zshrc ~/.zshrc_omz_backup && cp ~/.zshrc_alt ~/.zshrc"
  echo ""
  echo "Or test it first in a subshell:"
  echo "  ZDOTDIR=/tmp zsh -c 'source ~/.zshrc_alt'"
fi

echo ""
echo "=== Setup complete ==="

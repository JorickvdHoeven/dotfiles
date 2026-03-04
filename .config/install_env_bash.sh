#!/usr/bin/env bash
# ~/.config/install_env_bash.sh
# Full environment bootstrap for the bash setup (.custom_bashrc).
# Installs Homebrew (if missing), all brew dependencies, and clones dotfiles.

set -euo pipefail

echo "=== Bash Environment Setup ==="

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
  if sudo -n true 2>/dev/null; then
    echo "Installing Homebrew (system-wide)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  else
    echo "No sudo access — installing Homebrew to ~/environment/homebrew..."
    mkdir -p "${HOME}/environment"
    git clone https://github.com/Homebrew/brew.git "${HOME}/environment/homebrew"
    eval "$(${HOME}/environment/homebrew/bin/brew shellenv)"
    brew update --force --quiet
  fi
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

  # Bash completion
  bash-completion@2
)

echo "Installing brew packages..."
for pkg in "${brew_packages[@]}"; do
  if ! brew list "$pkg" &>/dev/null; then
    echo "  Installing $pkg..."
    brew install "$pkg"
  else
    echo "  $pkg already installed"
  fi
done
echo "✓ All packages installed"

# ── 4. Activate .custom_bashrc ──
if [[ -f "$HOME/.custom_bashrc" ]]; then
  # Add source line to .bashrc if not already present
  if ! grep -q 'source.*\.custom_bashrc' "$HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$HOME/.bashrc"
    echo "source ~/.custom_bashrc" >> "$HOME/.bashrc"
    echo "✓ Added 'source ~/.custom_bashrc' to ~/.bashrc"
  else
    echo "✓ .bashrc already sources .custom_bashrc"
  fi
fi

echo ""
echo "=== Setup complete ==="
echo "Start a new bash session or run: source ~/.bashrc"

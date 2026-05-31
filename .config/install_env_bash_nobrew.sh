#!/usr/bin/env bash
# ~/.config/install_env_bash_nobrew.sh
# Full environment bootstrap for the bash setup (.custom_bashrc).
# Installs tools from GitHub releases and source — no Homebrew required.
# Designed for devservers and environments where brew is unavailable.

set -euo pipefail

LOCAL_BIN="${HOME}/.local/bin"
LOCAL_SRC="${HOME}/.local/src"
mkdir -p "$LOCAL_BIN" "$LOCAL_SRC"

# Ensure ~/.local/bin is in PATH for this script
export PATH="${LOCAL_BIN}:${PATH}"

echo "=== Bash Environment Setup (no brew) ==="

# ── Helpers ──
# Detect OS and arch for downloading correct binaries
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)  ARCH_ALT="x86_64"; ARCH_GO="amd64" ;;
  aarch64) ARCH_ALT="aarch64"; ARCH_GO="arm64" ;;
  arm64)   ARCH_ALT="aarch64"; ARCH_GO="arm64" ;;
  *)       echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

# Get latest release tag from GitHub API
gh_latest() {
  local repo="$1"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4
}

# Download and extract a tarball, placing binaries in LOCAL_BIN
install_from_tarball() {
  local url="$1"
  local binary="$2"
  local tmpdir
  tmpdir="$(mktemp -d)"
  echo "  Downloading ${binary}..."
  curl -fsSL "$url" | tar -xz -C "$tmpdir"
  find "$tmpdir" -name "$binary" -type f -exec cp {} "$LOCAL_BIN/" \;
  chmod +x "$LOCAL_BIN/$binary"
  rm -rf "$tmpdir"
}

install_from_zip() {
  local url="$1"
  local binary="$2"
  local tmpdir
  tmpdir="$(mktemp -d)"
  echo "  Downloading ${binary}..."
  curl -fsSL "$url" -o "$tmpdir/archive.zip"
  unzip -qo "$tmpdir/archive.zip" -d "$tmpdir"
  find "$tmpdir" -name "$binary" -type f -exec cp {} "$LOCAL_BIN/" \;
  chmod +x "$LOCAL_BIN/$binary"
  rm -rf "$tmpdir"
}

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

# ── 2. Install tools from GitHub releases ──

# Starship
if ! command -v starship &>/dev/null; then
  echo "Installing starship..."
  curl -fsSL https://starship.rs/install.sh | sh -s -- --bin-dir "$LOCAL_BIN" --yes
else
  echo "  starship already installed"
fi

# fzf
if ! command -v fzf &>/dev/null; then
  tag="$(gh_latest junegunn/fzf)"
  ver="${tag#v}"
  install_from_tarball "https://github.com/junegunn/fzf/releases/download/${tag}/fzf-${ver}-${OS}_${ARCH_GO}.tar.gz" "fzf"
else
  echo "  fzf already installed"
fi

# fd
if ! command -v fd &>/dev/null; then
  tag="$(gh_latest sharkdp/fd)"
  ver="${tag#v}"
  install_from_tarball "https://github.com/sharkdp/fd/releases/download/${tag}/fd-${ver}-${ARCH_ALT}-unknown-${OS}-gnu.tar.gz" "fd"
else
  echo "  fd already installed"
fi

# eza
if ! command -v eza &>/dev/null; then
  tag="$(gh_latest eza-community/eza)"
  ver="${tag#v}"
  install_from_tarball "https://github.com/eza-community/eza/releases/download/${tag}/eza_${ARCH_ALT}-unknown-${OS}-gnu.tar.gz" "eza"
else
  echo "  eza already installed"
fi

# bat
if ! command -v bat &>/dev/null; then
  tag="$(gh_latest sharkdp/bat)"
  ver="${tag#v}"
  install_from_tarball "https://github.com/sharkdp/bat/releases/download/${tag}/bat-${ver}-${ARCH_ALT}-unknown-${OS}-gnu.tar.gz" "bat"
else
  echo "  bat already installed"
fi

# zoxide
if ! command -v zoxide &>/dev/null; then
  tag="$(gh_latest ajeetdsouza/zoxide)"
  ver="${tag#v}"
  install_from_tarball "https://github.com/ajeetdsouza/zoxide/releases/download/${tag}/zoxide-${ver}-${ARCH_ALT}-unknown-${OS}-musl.tar.gz" "zoxide"
else
  echo "  zoxide already installed"
fi

# direnv
if ! command -v direnv &>/dev/null; then
  tag="$(gh_latest direnv/direnv)"
  ver="${tag#v}"
  echo "  Downloading direnv..."
  curl -fsSL "https://github.com/direnv/direnv/releases/download/${tag}/direnv.${OS}-${ARCH_GO}" -o "$LOCAL_BIN/direnv"
  chmod +x "$LOCAL_BIN/direnv"
else
  echo "  direnv already installed"
fi

# delta
if ! command -v delta &>/dev/null; then
  tag="$(gh_latest dandavison/delta)"
  ver="${tag}"
  install_from_tarball "https://github.com/dandavison/delta/releases/download/${tag}/delta-${ver}-${ARCH_ALT}-unknown-${OS}-gnu.tar.gz" "delta"
else
  echo "  delta already installed"
fi

# neovim
if ! command -v nvim &>/dev/null; then
  tag="$(gh_latest neovim/neovim)"
  if [[ "$OS" == "linux" ]]; then
    install_from_tarball "https://github.com/neovim/neovim/releases/download/${tag}/nvim-${OS}-${ARCH_ALT}.tar.gz" "nvim"
  else
    echo "  Skipping neovim (install manually on macOS)"
  fi
else
  echo "  neovim already installed"
fi

echo "✓ All tools installed to ${LOCAL_BIN}"

# ── 3. Activate .custom_bashrc ──
if [[ -f "$HOME/.custom_bashrc" ]]; then
  # Ensure ~/.local/bin is in the bashrc
  if ! grep -q '\.local/bin' "$HOME/.custom_bashrc" 2>/dev/null; then
    echo "" >> "$HOME/.custom_bashrc"
    echo '# Local binaries (no-brew install)' >> "$HOME/.custom_bashrc"
    echo 'export PATH="${HOME}/.local/bin:${PATH}"' >> "$HOME/.custom_bashrc"
    echo "✓ Added ~/.local/bin to PATH in .custom_bashrc"
  fi

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
echo "Tools installed to: ${LOCAL_BIN}"
echo "Start a new bash session or run: source ~/.bashrc"

#!/usr/bin/env zsh
# ~/.config/environment/zsh-update.sh
# Ensures all brew-based zsh dependencies are installed and up to date.
# Runs weekly, triggered by .zshrc.
# Uses Homebrew packages instead of git clones.

ENVIRONMENT_DIR="${HOME}/.config/environment"
STAMP_FILE="${ENVIRONMENT_DIR}/.last_update"
LOG_FILE="${ENVIRONMENT_DIR}/.update.log"
LOCK_FILE="${ENVIRONMENT_DIR}/.update.lock"

# All dependencies managed via brew
brew_packages=(
  starship
  zsh-syntax-highlighting
  zsh-autosuggestions
  zsh-completions
  fzf
  fd
  eza
  bat
  zoxide
  direnv
  neovim
  git-delta
)

# ── Atomic lock via mkdir ──
if ! mkdir "$LOCK_FILE" 2>/dev/null; then
  # Check for stale lock (older than 10 minutes)
  lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
  if (( lock_age > 600 )); then
    rm -rf "$LOCK_FILE"
    mkdir "$LOCK_FILE" 2>/dev/null || exit 0
  else
    exit 0
  fi
fi
trap 'rm -rf "$LOCK_FILE"' EXIT INT TERM

# ── Helpers ──
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" }

# ── Ensure brew is available ──
if [[ -f "${HOME}/environment/homebrew/bin/brew" ]]; then
  eval "$(${HOME}/environment/homebrew/bin/brew shellenv)"
elif [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command -v brew &>/dev/null; then
  log "ERROR: brew not found, cannot proceed"
  exit 1
fi

# ── Main ──
log "=== Starting zsh dependency update ==="

errors=()

# Install missing packages
for pkg in "${brew_packages[@]}"; do
  if ! brew list "$pkg" &>/dev/null; then
    log "Installing ${pkg}"
    if ! brew install "$pkg" >> "$LOG_FILE" 2>&1; then
      log "ERROR: Failed to install ${pkg}"
      errors+=("Failed to install ${pkg}")
    fi
  fi
done

# Upgrade all managed packages
log "Upgrading installed packages"
for pkg in "${brew_packages[@]}"; do
  if brew list "$pkg" &>/dev/null; then
    if ! brew upgrade "$pkg" >> "$LOG_FILE" 2>&1; then
      # brew upgrade exits non-zero if already up to date — not an error
      if brew outdated "$pkg" &>/dev/null; then
        log "WARNING: ${pkg} upgrade returned non-zero (may already be current)"
      fi
    fi
  fi
done

# ── Notify user of errors in a separate terminal window ──
if (( ${#errors[@]} > 0 )); then
  log "Errors occurred, opening terminal to notify user"

  notify_script=$(mktemp /tmp/zsh-update-notify.XXXXXX.sh)
  {
    echo '#!/usr/bin/env zsh'
    echo 'echo "Zsh dependency update encountered errors:\n"'
    for e in "${errors[@]}"; do
      echo "echo '  - ${e}'"
    done
    echo ''
    echo "echo '\nFull log: ${LOG_FILE}\n'"
    echo 'echo "Press Enter to close."'
    echo 'read'
    echo "rm -f '${notify_script}'"
  } > "$notify_script"
  chmod +x "$notify_script"

  osascript <<APPLESCRIPT 2>/dev/null
tell application "Terminal"
  do script "${notify_script}"
end tell
APPLESCRIPT
fi

date +%s > "$STAMP_FILE"
log "=== Update complete ==="

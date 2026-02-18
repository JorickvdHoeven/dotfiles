#!/usr/bin/env zsh
# ~/.config/environment/zsh-update.sh
# Background updater for zsh plugins. Runs weekly, triggered by .zshrc.
# - Installs missing plugins, pulls updates for existing ones
# - Opens a new Terminal window to notify the user if errors occur

ENVIRONMENT_DIR="${HOME}/.config/environment"
STAMP_FILE="${ENVIRONMENT_DIR}/.last_update"
LOG_FILE="${ENVIRONMENT_DIR}/.update.log"
LOCK_FILE="${ENVIRONMENT_DIR}/.update.lock"

plugins=(
  "powerlevel10k|https://github.com/romkatv/powerlevel10k.git"
  "fzf-tab|https://github.com/Aloxaf/fzf-tab.git"
  "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git"
  "zsh-completions|https://github.com/zsh-users/zsh-completions.git"
  "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git"
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

# ── Main ──
log "=== Starting zsh plugin update ==="

errors=()

for entry in "${plugins[@]}"; do
  name="${entry%%|*}"
  url="${entry#*|}"
  dir="${ENVIRONMENT_DIR}/${name}"

  if [[ ! -d "$dir" ]]; then
    log "Installing ${name}"
    if ! GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$url" "$dir" >> "$LOG_FILE" 2>&1; then
      log "ERROR: Failed to clone ${name}"
      errors+=("Failed to install ${name}")
    fi
  else
    log "Updating ${name}"
    if ! GIT_TERMINAL_PROMPT=0 git -C "$dir" pull --ff-only >> "$LOG_FILE" 2>&1; then
      log "Fast-forward failed for ${name}, resetting to origin"
      if ! { GIT_TERMINAL_PROMPT=0 git -C "$dir" fetch origin >> "$LOG_FILE" 2>&1 && \
             git -C "$dir" reset --hard origin/HEAD >> "$LOG_FILE" 2>&1; }; then
        log "ERROR: Failed to update ${name}"
        errors+=("Failed to update ${name}")
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
    echo 'echo "Zsh plugin update encountered errors:\n"'
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

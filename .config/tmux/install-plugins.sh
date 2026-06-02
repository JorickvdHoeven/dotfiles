#!/usr/bin/env bash
# Robust TPM bootstrap + plugin installer for tmux.
# Fixes the flaky first-run experience: retries failed clones, runs shallow,
# and prints visible progress (TPM's inline bootstrap hides all of this).
#
# Usage:
#   ~/.config/tmux/install-plugins.sh          # install/verify all plugins
#   ~/.config/tmux/install-plugins.sh --force   # wipe & reinstall everything
set -uo pipefail

TMUX_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux"
PLUGIN_DIR="$TMUX_DIR/plugins"
TPM_DIR="$PLUGIN_DIR/tpm"
RETRIES=3

log()  { printf '\033[1;34m[tmux-plugins]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  ⚠\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m  ✗\033[0m %s\n' "$*"; }

[ "${1:-}" = "--force" ] && { log "Force mode: removing all plugins"; rm -rf "$PLUGIN_DIR"; }
mkdir -p "$PLUGIN_DIR"

# Clone a repo with retries + shallow depth. $1=url $2=dest
clone_retry() {
  local url="$1" dest="$2" name attempt
  name="$(basename "$dest")"
  [ -d "$dest/.git" ] && { ok "$name (already present)"; return 0; }
  for attempt in $(seq 1 "$RETRIES"); do
    if git clone --depth 1 --single-branch "$url" "$dest" >/dev/null 2>&1; then
      ok "$name"
      return 0
    fi
    rm -rf "$dest"
    warn "$name clone failed (attempt $attempt/$RETRIES)"
    sleep 2
  done
  err "$name FAILED after $RETRIES attempts"
  return 1
}

# 1. TPM itself
clone_retry "https://github.com/tmux-plugins/tpm" "$TPM_DIR" || exit 1

# 2. Parse @plugin lines from tmux.conf and install each
fail=0
while IFS= read -r repo; do
  [ -z "$repo" ] && continue
  [ "$repo" = "tmux-plugins/tpm" ] && continue
  clone_retry "https://github.com/$repo" "$PLUGIN_DIR/$(basename "$repo")" || fail=1
done < <(grep -E "^[[:space:]]*set -g @plugin " "$TMUX_DIR/tmux.conf" \
           | sed -E "s/.*@plugin '([^']+)'.*/\1/" | sort -u)

echo
if [ "$fail" -eq 0 ]; then
  log "All plugins installed. Reloading tmux if running…"
  tmux source-file "$TMUX_DIR/tmux.conf" 2>/dev/null && ok "reloaded" || true
else
  err "Some plugins failed — rerun: ~/.config/tmux/install-plugins.sh"
  exit 1
fi

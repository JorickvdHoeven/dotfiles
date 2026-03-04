#!/usr/bin/env bash
# ~/.config/delta-pager.sh
# Wrapper that switches delta between side-by-side and inline based on terminal width.

MIN_WIDTH=125

if [[ $(tput cols) -ge $MIN_WIDTH ]]; then
  delta --side-by-side "$@"
else
  delta "$@"
fi

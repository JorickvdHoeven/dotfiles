#!/usr/bin/env bash
# =============================================================================
# Theme: Tokyo Night (Storm) — custom for jorick
# =============================================================================
# Identical to the built-in tokyo-night/storm theme, EXCEPT statusbar-bg is a
# tmux conditional format instead of a static hex:
#
#   normal       -> #1a1b26  (darker bar than storm's #292e42)
#   prefix held  -> #e0af68  (flashes the mode-indicator color across the bar)
#
# PowerKit injects statusbar-bg verbatim into every cap/separator/gap backdrop,
# and tmux evaluates the #{?client_prefix,...} at render time — so the WHOLE bar
# (caps included) shifts to the mode color with NO mismatched notch.
# status-style and status-format[1] in tmux.conf use the SAME expression.
# =============================================================================

declare -gA THEME_COLORS=(
    # Status Bar — dynamic: dark normally, mode-color on prefix.
    # Bar flash (#b38c53) is a shade darker than the session prefix pill
    # (#e0af68) so the pill stands out against the bar.
    [statusbar-bg]="#{?client_prefix,#b38c53,#1a1b26}"
    [statusbar-fg]="#c0caf5"

    # Session
    [session-bg]="#9ece6a"
    [session-fg]="#24283b"
    [session-prefix-bg]="#e0af68"
    [session-copy-bg]="#7dcfff"

    # Windows (base colors - variants auto-generated)
    [window-active-base]="#bb9af7"
    [window-inactive-base]="#3b4261"

    # Pane Borders
    [pane-border-active]="#7aa2f7"
    [pane-border-inactive]="#3b4261"

    # Health States (base colors - variants auto-generated)
    [ok-base]="#394b70"
    [good-base]="#9ece6a"
    [info-base]="#7dcfff"
    [warning-base]="#e0af68"
    [error-base]="#f7768e"
    [disabled-base]="#565f89"

    # Messages
    [message-bg]="#292e42"
    [message-fg]="#c0caf5"

    # Popup & Menu
    [popup-bg]="#292e42"
    [popup-fg]="#c0caf5"
    [popup-border]="#7aa2f7"
    [menu-bg]="#292e42"
    [menu-fg]="#c0caf5"
    [menu-selected-bg]="#9ece6a"
    [menu-selected-fg]="#24283b"
    [menu-border]="#7aa2f7"
)

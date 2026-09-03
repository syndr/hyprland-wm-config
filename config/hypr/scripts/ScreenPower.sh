#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Single entry point for turning the displays on and off.
#
# Everything in this config that used to call `hyprctl dispatch dpms on|off`
# directly goes through here instead, so the swaylock-plugin screensaver is
# paused whenever the panel goes dark and resumed when it comes back. See
# ScreensaverPause.sh for why the hack does not stop on its own.
#
# Usage: ScreenPower.sh on|off

set -u

# Default to this script's own directory: the idle helpers always ship
# together, so they resolve correctly from a checkout as well as from a
# deploy. IDLE_SCRIPTS_DIR overrides (the installer points it at its
# staging tree).
SCRIPTS_DIR="${IDLE_SCRIPTS_DIR:-$(cd "$(dirname "$(readlink -f "$0")")" && pwd)}"
PAUSE="$SCRIPTS_DIR/ScreensaverPause.sh"
# shellcheck source=./lib_idle_settings.sh
. "$SCRIPTS_DIR/lib_idle_settings.sh"
IDLE_LOG_TAG=screen

# One wake can arrive from three hypridle rules at once (each blanking rule
# carries its own on-resume). Serialise on fd 7 -- distinct from the fd 8 lock
# inside ScreensaverPause.sh and the fd 9 instance lock, so the nesting cannot
# deadlock -- and act only on a real transition, so redundant callers neither
# re-dispatch to Hyprland nor add a log line.
POWER_LOCK="${XDG_RUNTIME_DIR:-/tmp}/kool-idle/screenpower.lock"
mkdir -p "$(dirname "$POWER_LOCK")" 2>/dev/null
if command -v flock >/dev/null 2>&1 && exec 7>"$POWER_LOCK" 2>/dev/null; then
    flock -w 5 7 2>/dev/null || true
fi

screen_is_on() {
    # Fail towards "off" when Hyprland cannot be reached, so a wake still
    # dispatches rather than being silently skipped.
    hyprctl monitors -j 2>/dev/null | grep -q '"dpmsStatus": *true'
}

locker_state() {
    pidof hyprlock swaylock-plugin >/dev/null 2>&1 && echo yes || echo no
}

case "${1:-}" in
    on)
        if ! screen_is_on; then
            idle_log "dpms on (locker: $(locker_state))"
            hyprctl dispatch dpms on >/dev/null 2>&1
        fi
        # Always resume, even when another caller already lit the panel: the
        # hack must not be left stopped behind a visible screen.
        [ -x "$PAUSE" ] && "$PAUSE" resume
        ;;
    off)
        # Park the outputs first: pausing while the panel is still lit would
        # freeze a visible frame for a beat.
        if screen_is_on; then
            idle_log "dpms off (locker: $(locker_state))"
            hyprctl dispatch dpms off >/dev/null 2>&1
        fi
        [ -x "$PAUSE" ] && "$PAUSE" pause
        ;;
    *)
        echo "Usage: $0 {on|off}" >&2
        exit 1
        ;;
esac

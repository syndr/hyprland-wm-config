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

case "${1:-}" in
    on)
        idle_log "dpms on (locker: $(pidof hyprlock swaylock-plugin >/dev/null 2>&1 && echo yes || echo no))"
        hyprctl dispatch dpms on >/dev/null 2>&1
        # Resume after the panel is lit, so the hack's first frame lands on a
        # visible screen rather than being drawn into the dark.
        [ -x "$PAUSE" ] && "$PAUSE" resume
        ;;
    off)
        # Park the outputs first: pausing while the panel is still lit would
        # freeze a visible frame for a beat.
        idle_log "dpms off (locker: $(pidof hyprlock swaylock-plugin >/dev/null 2>&1 && echo yes || echo no))"
        hyprctl dispatch dpms off >/dev/null 2>&1
        [ -x "$PAUSE" ] && "$PAUSE" pause
        ;;
    *)
        echo "Usage: $0 {on|off}" >&2
        exit 1
        ;;
esac

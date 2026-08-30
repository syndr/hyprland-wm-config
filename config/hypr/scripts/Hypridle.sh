#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# This is for custom version of waybar idle_inhibitor which activates / deactivates hypridle instead

PROCESS="hypridle"

if [[ "$1" == "status" ]]; then
    sleep 1
    if pgrep -x "$PROCESS" >/dev/null; then
        echo '{"text": "RUNNING", "class": "active", "tooltip": "idle_inhibitor NOT ACTIVE\nLeft Click: Activate\nRight Click: Lock Screen"}'
    else
        echo '{"text": "NOT RUNNING", "class": "notactive", "tooltip": "idle_inhibitor is ACTIVE\nLeft Click: Deactivate\nRight Click: Lock Screen"}'
    fi
elif [[ "$1" == "toggle" ]]; then
    if pgrep -x "$PROCESS" >/dev/null; then
        pkill "$PROCESS"
    else
        "$PROCESS" >/dev/null 2>&1 &
        disown
    fi
elif [[ "$1" == "reload" ]]; then
    # Pick up a regenerated hypridle.conf. hypridle has no reload signal, so
    # this is a restart -- which resets every idle timer, hence the callers
    # (GenerateHypridle.sh --restart, IdlePowerWatch.sh) taking care about
    # when they ask for it.
    #
    # Deliberately a no-op when hypridle is not running: the waybar toggle
    # above is the user's idle-inhibit switch, and a reload must not undo it.
    if pgrep -x "$PROCESS" >/dev/null; then
        pkill -x "$PROCESS"
        # Wait for the old instance to release its idle-notify objects before
        # starting the new one, so both are never registered at once.
        for _ in {1..20}; do
            pgrep -x "$PROCESS" >/dev/null || break
            sleep 0.1
        done
        "$PROCESS" >/dev/null 2>&1 &
        disown
    fi
else
    echo "Usage: $0 {status|toggle|reload}"
    exit 1
fi

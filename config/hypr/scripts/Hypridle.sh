#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# This is for custom version of waybar idle_inhibitor which activates / deactivates hypridle instead

PROCESS="hypridle"

# hypridle's own output (listener registration, spawn failures) was going to
# /dev/null, so a misfiring listener left no trace anywhere. Truncate on each
# start rather than appending: hypridle restarts on every power-profile flip
# and at login, which keeps the file bounded without needing rotation, and a
# fresh file always describes the config currently loaded.
HYPRIDLE_LOG="${HYPRIDLE_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/kool-dots/hypridle.log}"
start_hypridle() {
    mkdir -p "$(dirname "$HYPRIDLE_LOG")" 2>/dev/null
    "$PROCESS" >"$HYPRIDLE_LOG" 2>&1 &
    disown
}

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
        start_hypridle
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
        start_hypridle
    fi
else
    echo "Usage: $0 {status|toggle|reload}"
    exit 1
fi

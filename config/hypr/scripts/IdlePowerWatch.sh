#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Keep hypridle's timeouts matched to the power source.
#
# hypridle has no way to vary a timeout by AC/battery state, so
# GenerateHypridle.sh renders one profile at a time and this watcher
# re-renders and reloads when the charger is plugged or unplugged. Portable
# hardware wants a much shorter leash on battery than on the desk.
#
# Event-driven: it blocks on udev's power_supply uevents rather than polling.
# The read timeout only exists to (a) apply a reload that was deferred while
# the session was locked and (b) self-heal if a uevent is ever missed.
#
# Started from Startup_Apps.conf / startup.lua alongside hypridle itself.

set -u

# Default to this script's own directory: the idle helpers always ship
# together, so they resolve correctly from a checkout as well as from a
# deploy. IDLE_SCRIPTS_DIR overrides (the installer points it at its
# staging tree).
SCRIPTS_DIR="${IDLE_SCRIPTS_DIR:-$(cd "$(dirname "$(readlink -f "$0")")" && pwd)}"
# shellcheck source=./lib_idle_settings.sh
. "$SCRIPTS_DIR/lib_idle_settings.sh"
IDLE_LOG_TAG=power

GENERATE="$SCRIPTS_DIR/GenerateHypridle.sh"
HYPRIDLE="$SCRIPTS_DIR/Hypridle.sh"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf"

# Nothing to do when the user has taken hypridle.conf back into their own
# hands, or when the generator is missing.
[ "$(idle_knob_bool KOOL_IDLE_MANAGED 1)" = "1" ] || exit 0
[ -x "$GENERATE" ] || exit 0

idle_single_instance idlepowerwatch || exit 0

IDLE_POLL_PENDING="${KOOL_IDLE_POWER_POLL_PENDING:-5}"
IDLE_POLL_IDLE="${KOOL_IDLE_POWER_POLL_IDLE:-300}"
IDLE_DEBOUNCE="${KOOL_IDLE_POWER_DEBOUNCE:-2}"

conf_sum() { [ -f "$CONF" ] && cksum <"$CONF" || echo none; }

locker_running() { pidof hyprlock swaylock-plugin >/dev/null 2>&1; }

pending=0

# Reloading restarts hypridle, which resets every idle timer. Doing that
# mid-lock would re-arm the screen-blank window from zero and light the panel
# back up, so a reload requested while locked waits for the unlock.
maybe_reload() {
    if locker_running; then
        idle_log "reload deferred -- session is locked (timers would reset mid-lock)"
        pending=1
        return 0
    fi
    # 9>&- keeps the single-instance lock out of hypridle, which we are about
    # to start and which outlives us. Inheriting it would pin the lock for the
    # rest of the session and stop this watcher ever restarting.
    "$HYPRIDLE" reload >/dev/null 2>&1 9>&-
    [ "$pending" = "1" ] && idle_log "deferred reload applied"
    pending=0
}

profile=$(idle_power_profile)
before=$(conf_sum)
"$GENERATE" --profile "$profile" 9>&-
if [ "$(conf_sum)" != "$before" ]; then
    idle_log "started on $profile -- config was stale, regenerated"
    maybe_reload
else
    idle_log "started on $profile -- config already current"
fi

# Open the uevent stream on its own descriptor rather than redirecting the
# loop, so the child's pid is capturable and it can be cleaned up on exit.
#
# `exec 9>&-` inside the substitution is load-bearing: fd 9 is the
# single-instance flock, and a process-substitution child inherits it. Without
# the close, killing this script orphans a udevadm that keeps holding the lock
# -- after which every restart sees the lock held, exits "already running", and
# the watcher can never come back until that udevadm is killed by hand.
exec {UDEV_FD}< <(exec 9>&-; udevadm monitor --udev --subsystem-match=power_supply 2>/dev/null)
udev_pid=$!
# A signal trap that only cleans up does not stop the script -- bash resumes
# the loop afterwards. Handle EXIT and the signals separately so a TERM
# actually terminates us instead of dropping through to the loop below with a
# dead descriptor.
cleanup_udev() { kill "$udev_pid" 2>/dev/null; }
trap cleanup_udev EXIT
trap 'cleanup_udev; exit 0' INT TERM

while :; do
    if [ "$pending" = "1" ]; then poll="$IDLE_POLL_PENDING"; else poll="$IDLE_POLL_IDLE"; fi

    if read -r -t "$poll" line <&"$UDEV_FD"; then
        case "$line" in
            *power_supply*) sleep "$IDLE_DEBOUNCE" ;;
            *) continue ;;
        esac
    else
        # bash returns >128 when `read -t` times out and <=128 on EOF. EOF
        # means udevadm died: without this the loop would spin on an exhausted
        # descriptor, burning CPU on battery for as long as the session lasts.
        rc=$?
        if [ "$rc" -le 128 ]; then
            idle_log "uevent stream closed (rc=$rc) -- exiting so it can be restarted"
            exit 1
        fi
    fi

    now=$(idle_power_profile)
    if [ "$now" != "$profile" ]; then
        idle_log "power changed: $profile -> $now"
        profile="$now"
        "$GENERATE" --profile "$profile" 9>&-
        maybe_reload
    elif [ "$pending" = "1" ]; then
        maybe_reload
    fi
done

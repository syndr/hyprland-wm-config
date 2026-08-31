#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Stop the swaylock-plugin screensaver from burning power while the panel is
# dark.
#
# swaylock-plugin has no DPMS handling of its own. It forwards the plugin
# client's buffers straight through (forward.c), so throttling only happens
# for clients that draw on wl_surface::frame callbacks. An xscreensaver hack
# running under Xwayland + windowtolayer renders on its own clock and keeps
# decoding/compositing at full rate with the screen off -- on a handheld that
# is real battery drain.
#
# SIGSTOP, not SIGKILL: swaylock-plugin re-runs the command whenever the
# client disconnects (client_destroyed() -> run_plugin_command(..., "restarting")),
# so killing the hack just respawns it. Stopping is also safe against the
# "client failed to redraw -> permanent solid-colour fallback" path: that 4s
# timer only arms at output creation and on size-change configures, never
# periodically, so an arbitrarily long stop cannot trip it.
#
# swaylock-plugin spawns its child with posix_spawn's setsid flag, so the
# hack, Xwayland and windowtolayer share one process group that is distinct
# from swaylock-plugin's own -- signalling that group pauses the whole tree
# without touching the locker itself.
#
# Usage:
#   ScreensaverPause.sh pause     stop the hack process group(s)
#   ScreensaverPause.sh resume    continue them (idempotent, always safe)
#   ScreensaverPause.sh status    print running|paused|none
#   ScreensaverPause.sh watch     follow the screen state until the locker exits

set -u

# Default to this script's own directory: the idle helpers always ship
# together, so they resolve correctly from a checkout as well as from a
# deploy. IDLE_SCRIPTS_DIR overrides (the installer points it at its
# staging tree).
SCRIPTS_DIR="${IDLE_SCRIPTS_DIR:-$(cd "$(dirname "$(readlink -f "$0")")" && pwd)}"
# shellcheck source=./lib_idle_settings.sh
. "$SCRIPTS_DIR/lib_idle_settings.sh"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/kool-idle"
PAUSED_STAMP="$STATE_DIR/screensaver-paused"

self_pgid=$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')

# Process groups of swaylock-plugin's children -- the hack tree, never the
# locker itself.
screensaver_pgids() {
    local sl sl_pgid child cname pgid
    for sl in $(pidof swaylock-plugin 2>/dev/null); do
        sl_pgid=$(ps -o pgid= -p "$sl" 2>/dev/null | tr -d ' ')
        for child in $(pgrep -P "$sl" 2>/dev/null); do
            # swaylock-plugin daemonizes, so a "child" of one swaylock-plugin
            # process is often the other one (or swaylock-sleep-watcher).
            # Never signal swaylock's own processes: SIGSTOPping the locker
            # wedges the session behind a frozen lock surface. Matching on the
            # name is the reliable guard -- the process-group check below only
            # catches the fork while it stays in the locker's group.
            cname=$(ps -o comm= -p "$child" 2>/dev/null | tr -d ' ')
            case "$cname" in swaylock*|'') continue ;; esac
            pgid=$(ps -o pgid= -p "$child" 2>/dev/null | tr -d ' ')
            [ -n "$pgid" ] || continue
            [ "$pgid" = "$self_pgid" ] && continue
            [ -n "$sl_pgid" ] && [ "$pgid" = "$sl_pgid" ] && continue
            printf '%s\n' "$pgid"
        done
    done | sort -u
}

do_pause() {
    [ "$(idle_knob_bool KOOL_IDLE_SCREENSAVER_PAUSE 1)" = "1" ] || return 0
    pidof swaylock-plugin >/dev/null 2>&1 || return 0

    local pgids pgid stopped=1
    pgids=$(screensaver_pgids)
    [ -n "$pgids" ] || return 0
    for pgid in $pgids; do
        kill -STOP -- "-$pgid" 2>/dev/null && stopped=0
    done

    # Record what we stopped. The tree can only be *found* through
    # swaylock-plugin's children, so if the locker dies while we are stopped
    # there is nothing left to discover -- and a SIGSTOPped process cannot
    # notice its Wayland connection died and exit. Without this the hack tree
    # is orphaned in state T indefinitely.
    if [ "$stopped" = "0" ]; then
        mkdir -p "$STATE_DIR" 2>/dev/null
        printf '%s\n' $pgids >"$PAUSED_STAMP"
    fi
}

# Resume is deliberately unconditional: it must work even when pausing has
# since been disabled, so a stopped process tree can never be left behind.
do_resume() {
    local pgid recorded=""
    [ -f "$PAUSED_STAMP" ] && recorded=$(cat "$PAUSED_STAMP" 2>/dev/null)

    for pgid in $( { screensaver_pgids; printf '%s\n' $recorded; } | sort -u ); do
        [ -n "$pgid" ] || continue
        kill -CONT -- "-$pgid" 2>/dev/null
    done

    # Locker gone: the hack has no surface left to draw into. Now that it is
    # running again it will notice the dead Wayland connection and exit; reap
    # whatever lingers. Only ever done when swaylock-plugin is absent -- while
    # it lives, killing the client just makes it respawn one.
    if [ -n "$recorded" ] && ! pidof swaylock-plugin >/dev/null 2>&1; then
        sleep 1
        for pgid in $recorded; do
            [ -n "$pgid" ] || continue
            kill -TERM -- "-$pgid" 2>/dev/null
        done
    fi

    rm -f "$PAUSED_STAMP" 2>/dev/null
    return 0
}

do_status() {
    if ! pidof swaylock-plugin >/dev/null 2>&1; then
        echo none
    elif [ -e "$PAUSED_STAMP" ]; then
        echo paused
    else
        echo running
    fi
}

# The screen counts as off when the compositor has parked every output, OR
# when a backlight has been switched off behind the compositor's back. The
# second case is the uConsole power key: uconsole-sleep drives DRM/backlight
# directly, so Hyprland still believes its outputs are lit and keeps handing
# out frame callbacks.
screen_is_off() {
    local monitors bl
    monitors=$(hyprctl monitors -j 2>/dev/null)
    if [ -n "$monitors" ] && ! printf '%s' "$monitors" | grep -q '"dpmsStatus": *true'; then
        return 0
    fi
    for bl in /sys/class/backlight/*/bl_power; do
        [ -r "$bl" ] || continue
        [ "$(cat "$bl" 2>/dev/null)" = "0" ] || return 0
    done
    return 1
}

# Follow the screen state for as long as a locker is up. ScreenPower.sh
# already pauses/resumes on every DPMS transition this config drives; this
# loop is the safety net for screen-off that Hyprland never sees.
do_watch() {
    [ "$(idle_knob_bool KOOL_IDLE_SCREENSAVER_PAUSE 1)" = "1" ] || return 0
    [ "$(idle_knob_bool KOOL_IDLE_SCREENSAVER_PAUSE_WATCH 1)" = "1" ] || return 0

    local interval
    interval=$(idle_knob_int KOOL_IDLE_SCREENSAVER_PAUSE_INTERVAL 5)

    idle_single_instance screensaver-pause-watch || return 0

    # Started from SwaylockScreensaver.sh just before it execs the locker, so
    # give swaylock-plugin a moment to come up before deciding there is
    # nothing to watch. Also covers the hyprlock fallback path: if no
    # swaylock-plugin appears, there is no hack to pause and we exit quietly.
    local waited=0
    while ! pidof swaylock-plugin >/dev/null 2>&1; do
        [ "$waited" -ge 15 ] && return 0
        sleep 1
        waited=$(( waited + 1 ))
    done

    trap 'do_resume; exit 0' EXIT INT TERM

    local want_paused is_paused=0
    while pidof swaylock-plugin >/dev/null 2>&1; do
        if screen_is_off; then want_paused=1; else want_paused=0; fi
        if [ "$want_paused" != "$is_paused" ]; then
            if [ "$want_paused" = "1" ]; then do_pause; else do_resume; fi
            is_paused="$want_paused"
        fi
        sleep "$interval"
    done
}

case "${1:-}" in
    pause)  do_pause ;;
    resume) do_resume ;;
    status) do_status ;;
    watch)  do_watch ;;
    *)
        echo "Usage: $0 {pause|resume|status|watch}" >&2
        exit 1
        ;;
esac

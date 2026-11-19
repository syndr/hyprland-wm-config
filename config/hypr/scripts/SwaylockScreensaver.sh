#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Thin wrapper: the screensaver lockscreen logic lives in the packaged
# swaylock-screensaver (swaylock-plugin-screensaver RPM/deb; canonical source
# is swaylock-plugin's contrib/screensaver). This wrapper pins this config's
# paths and keeps hyprlock as the fallback locker, so hypridle's lock_cmd and
# the keybinds keep calling the same script they always did.
#
# Invoked by hypridle's lock_cmd (fires for CTRL+ALT+L, SUPER+grave, idle
# timeout, and before sleep -- all via loginctl lock-session). Hosts without
# the package fall through to hyprlock, silently.

command -v swaylock-screensaver >/dev/null || exec hyprlock -q

# Reap any hyprlock before the screensaver locker goes up. One can only be
# here as the fallback from an earlier swaylock-plugin crash, and with
# misc.allow_session_lock_restore the locker started below takes the session
# lock from it without telling it: it then survives the unlock, never gets
# another frame, and logs a label warning several times a second for good
# (and holds the "pidof hyprlock" dpms gates open). The compositor keeps the
# session locked while no lock client is attached, so this opens no gap.
#
# Each one gets a marker first. A fallback hyprlock is the tail of an earlier
# "SwaylockScreensaver.sh || hyprlock" still waiting in hypridle; if it just
# died, that shell would read it as a failed locker and start a fresh
# hyprlock, which this takeover would orphan all over again. The marker tells
# that earlier wrapper (below) the kill was deliberate.
REAP_DIR="${XDG_RUNTIME_DIR:-/tmp}"
for pid in $(pidof hyprlock 2>/dev/null); do
    : > "$REAP_DIR/kool-hyprlock-reaped.$pid"
    kill "$pid" 2>/dev/null || rm -f "$REAP_DIR/kool-hyprlock-reaped.$pid"
done

# Same state file the picker has always written; thumbnails from the
# pre-package cache location; recovery lands in hyprlock (fail-secure).
export HACK_STATE="${HACK_STATE:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/.swaylock_hack}"
export SCREENHACK_SHOT_DIR="${SCREENHACK_SHOT_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/screenhack-shots}"
export SWAYLOCK_SCREENSAVER_FALLBACK="${SWAYLOCK_SCREENSAVER_FALLBACK:-hyprlock}"

# Pause the hack whenever the panel goes dark. ScreenPower.sh already handles
# every DPMS transition this config drives; this watcher is the safety net for
# screen-off the compositor never sees (on the uConsole, the power key parks
# the panel through uconsole-sleep while Hyprland still thinks it is lit).
# It exits on its own when the locker does, and resumes the hack on the way
# out so a stopped process tree is never left behind.
SCRIPTS_DIR="${IDLE_SCRIPTS_DIR:-$(cd "$(dirname "$(readlink -f "$0")")" && pwd)}"
if [ -x "$SCRIPTS_DIR/ScreensaverPause.sh" ]; then
    setsid -f "$SCRIPTS_DIR/ScreensaverPause.sh" watch >/dev/null 2>&1 || true
fi

# Not exec'd: a swaylock-plugin that crashes or is killed has to land in
# hyprlock, and -q keeps that fallback out of the journal. hypridle's
# "|| hyprlock" stays behind this as the net for a wrapper that cannot run.
swaylock-screensaver "$@" && exit 0

# Not exec'd either: when a later lock trigger reaps this hyprlock (above),
# exit 0 so hypridle's "|| hyprlock" does not answer by starting another.
# Any other failure still propagates and lands in that net.
hyprlock -q &
fallback_pid=$!
rm -f "$REAP_DIR/kool-hyprlock-reaped.$fallback_pid"   # stale, from a reused pid
wait "$fallback_pid"
rc=$?
if [ -e "$REAP_DIR/kool-hyprlock-reaped.$fallback_pid" ]; then
    rm -f "$REAP_DIR/kool-hyprlock-reaped.$fallback_pid"
    exit 0
fi
exit "$rc"

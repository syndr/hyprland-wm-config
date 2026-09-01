#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Shared reader for UserConfigs/IdleSettings.conf, the single tuning surface
# for the idle/lock policy. Source this; do not execute it.
#
# IdleSettings.conf is user-owned and preserved across updates, so it is
# parsed with grep/sed and never sourced -- same discipline as
# read_idle_knob() in the installer's scripts/lib_detect.sh. Keep the two in
# sync if the parsing rules ever change.

IDLE_SETTINGS_FILE="${IDLE_SETTINGS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/IdleSettings.conf}"

# idle_knob KEY DEFAULT -- raw value, or DEFAULT when the file or key is
# absent, commented out, or set to an empty value.
idle_knob() {
    local key="$1" def="$2" val=""
    if [ -f "$IDLE_SETTINGS_FILE" ]; then
        val=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$IDLE_SETTINGS_FILE" 2>/dev/null | tail -1 \
            | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*#.*$//; s/["'\'']//g; s/[[:space:]]+$//')
    fi
    if [ -n "$val" ]; then printf '%s' "$val"; else printf '%s' "$def"; fi
}

# idle_knob_uint KEY DEFAULT -- non-negative integer; anything else falls back
# to DEFAULT. 0 is a meaningful value for some knobs (e.g. a warning lead of 0
# means "no pre-lock warning").
idle_knob_uint() {
    local v
    v=$(idle_knob "$1" "$2")
    case "$v" in ''|*[!0-9]*) v="$2" ;; esac
    printf '%s' "$v"
}

# idle_knob_int KEY DEFAULT -- strictly positive integer. Used for hypridle
# timeouts, which must be > 0 to be meaningful.
idle_knob_int() {
    local v
    v=$(idle_knob_uint "$1" "$2")
    if [ "$v" -le 0 ] 2>/dev/null; then v="$2"; fi
    printf '%s' "$v"
}

# idle_knob_bool KEY DEFAULT -- echoes 1 or 0.
idle_knob_bool() {
    local v
    v=$(idle_knob "$1" "$2")
    case "$v" in
        1|true|yes|on|TRUE|Yes|On|YES|ON) printf '1' ;;
        *) printf '0' ;;
    esac
}

# Which power profile applies right now. OnBattery.sh exits 0 on battery,
# 1 when a Mains supply is confirmed online, and fails open to "battery".
idle_power_profile() {
    local on_battery="${IDLE_SCRIPTS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts}/OnBattery.sh"
    # `bash <file>` covers the installer, which renders the config out of a
    # staging directory before the exec-bit pass has run.
    if [ -x "$on_battery" ]; then
        if "$on_battery"; then printf 'bat'; else printf 'ac'; fi
    elif [ -r "$on_battery" ]; then
        if bash "$on_battery"; then printf 'bat'; else printf 'ac'; fi
    else
        printf 'ac'
    fi
}

# idle_profile_knob BASENAME PROFILE DEFAULT
# Resolves KOOL_IDLE_<BASENAME>_<AC|BAT>, falling back to the legacy
# un-suffixed KOOL_IDLE_<BASENAME> (so a pre-existing KOOL_IDLE_LOCK_TIMEOUT
# still seeds both profiles), then to DEFAULT.
idle_profile_knob() {
    local base="$1" profile="$2" def="$3" legacy
    legacy=$(idle_knob_int "KOOL_IDLE_${base}" "$def")
    idle_knob_int "KOOL_IDLE_${base}_$(printf '%s' "$profile" | tr '[:lower:]' '[:upper:]')" "$legacy"
}

# Single-instance guard. A flock on an fd is atomic and released automatically
# when the process dies -- unlike matching our own name in the process table,
# which also matches any wrapper whose command line contains this script's
# path (setsid, timeout, sh -c ...) and would make us exit as a false positive.
#
# CAUTION: the lock lives on fd 9 (IDLE_LOCK_FD) and children inherit it. A
# child that outlives this process keeps the lock held, and every future start
# then exits as "already running" -- the guard turns into a permanent block.
# Spawn anything long-lived with the descriptor closed:
#
#     some-daemon "$@" 9>&-
#
IDLE_LOCK_FD=9
idle_single_instance() { # idle_single_instance LOCKNAME
    local lock_dir="${XDG_RUNTIME_DIR:-/tmp}/kool-idle"
    mkdir -p "$lock_dir" 2>/dev/null || return 0
    command -v flock >/dev/null 2>&1 || return 0
    exec 9>"$lock_dir/$1.lock" || return 0
    flock -n 9 || return 1
    return 0
}

# --- logging ------------------------------------------------------------
# The idle stack is a set of small scripts fired by hypridle and udev, with no
# terminal attached and their output going to /dev/null, so after the fact
# there is no way to tell what it did -- when the screensaver paused, whether a
# power flip was picked up, whether a reload was deferred because the session
# was locked. One shared append-only log makes those answerable.
#
# Volume is a handful of lines per lock cycle. KOOL_IDLE_LOG=0 disables it.
IDLE_LOG_FILE="${IDLE_LOG_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/kool-dots/idle.log}"
IDLE_LOG_MAX_LINES="${IDLE_LOG_MAX_LINES:-500}"

idle_log() {
    [ "$(idle_knob_bool KOOL_IDLE_LOG 1)" = "1" ] || return 0
    mkdir -p "$(dirname "$IDLE_LOG_FILE")" 2>/dev/null || return 0
    printf '%s  %-12s %s\n' "$(date '+%m-%d %H:%M:%S')" "${IDLE_LOG_TAG:-idle}" "$*" \
        >>"$IDLE_LOG_FILE" 2>/dev/null || return 0

    # Bounded growth without rewriting the file on every line: only compact
    # once it has drifted well past the cap.
    local lines
    lines=$(wc -l <"$IDLE_LOG_FILE" 2>/dev/null || echo 0)
    if [ "$lines" -gt $(( IDLE_LOG_MAX_LINES * 2 )) ] 2>/dev/null; then
        if tail -n "$IDLE_LOG_MAX_LINES" "$IDLE_LOG_FILE" >"$IDLE_LOG_FILE.tmp" 2>/dev/null; then
            mv -f "$IDLE_LOG_FILE.tmp" "$IDLE_LOG_FILE" 2>/dev/null
        else
            rm -f "$IDLE_LOG_FILE.tmp" 2>/dev/null
        fi
    fi
    return 0
}

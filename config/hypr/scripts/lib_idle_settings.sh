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
idle_single_instance() { # idle_single_instance LOCKNAME
    local lock_dir="${XDG_RUNTIME_DIR:-/tmp}/kool-idle"
    mkdir -p "$lock_dir" 2>/dev/null || return 0
    command -v flock >/dev/null 2>&1 || return 0
    exec 9>"$lock_dir/$1.lock" || return 0
    flock -n 9 || return 1
    return 0
}

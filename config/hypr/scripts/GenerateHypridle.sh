#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Render ~/.config/hypr/hypridle.conf from UserConfigs/IdleSettings.conf.
#
# hypridle listeners take absolute seconds counted from the last input event,
# which makes a hand-written config hard to read: "1800" only means anything
# once you know it is "lock at 600, then animate for 1200". Here every knob is
# relative and named -- lock timeout, warning lead, blank delay, screensaver
# window -- and this script does the arithmetic.
#
# hypridle cannot vary a timeout by power state, so the generated file holds a
# single profile (AC or battery). IdlePowerWatch.sh re-runs this script and
# reloads hypridle when the charger is plugged or unplugged.
#
# Usage:
#   GenerateHypridle.sh                 write ~/.config/hypr/hypridle.conf
#   GenerateHypridle.sh --print         write to stdout instead
#   GenerateHypridle.sh --output PATH   write somewhere else
#   GenerateHypridle.sh --profile ac    force a profile instead of detecting
#   GenerateHypridle.sh --restart       write, then reload hypridle

set -u

# Default to this script's own directory: the idle helpers always ship
# together, so they resolve correctly from a checkout as well as from a
# deploy. IDLE_SCRIPTS_DIR overrides (the installer points it at its
# staging tree).
SCRIPTS_DIR="${IDLE_SCRIPTS_DIR:-$(cd "$(dirname "$(readlink -f "$0")")" && pwd)}"
# shellcheck source=./lib_idle_settings.sh
. "$SCRIPTS_DIR/lib_idle_settings.sh"

OUTPUT="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf"
TO_STDOUT=0
PROFILE=""
RESTART=0

while [ $# -gt 0 ]; do
    case "$1" in
        --print) TO_STDOUT=1 ;;
        --output) OUTPUT="${2:?--output needs a path}"; shift ;;
        --profile) PROFILE="${2:?--profile needs ac|bat}"; shift ;;
        --restart) RESTART=1 ;;
        -h|--help)
            cat <<'USAGE'
Render ~/.config/hypr/hypridle.conf from UserConfigs/IdleSettings.conf.

  GenerateHypridle.sh                 write ~/.config/hypr/hypridle.conf
  GenerateHypridle.sh --print         write to stdout instead
  GenerateHypridle.sh --output PATH   write somewhere else
  GenerateHypridle.sh --profile ac    force a profile instead of detecting
  GenerateHypridle.sh --restart       write, then reload hypridle
USAGE
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

case "$PROFILE" in
    ac|bat) ;;
    "") PROFILE=$(idle_power_profile) ;;
    *) echo "--profile must be ac or bat" >&2; exit 1 ;;
esac

# Profile defaults. Battery is deliberately much tighter: this config targets
# portable hardware, where a 20-minute animated lockscreen is a real drain.
if [ "$PROFILE" = "bat" ]; then
    DEF_LOCK=300; DEF_DPMS_DELAY=15; DEF_SCREENSAVER=120; PROFILE_LABEL="battery"
else
    DEF_LOCK=900; DEF_DPMS_DELAY=15; DEF_SCREENSAVER=1200; PROFILE_LABEL="AC"
fi

LOCK=$(idle_profile_knob LOCK_TIMEOUT "$PROFILE" "$DEF_LOCK")
DPMS_DELAY=$(idle_profile_knob DPMS_DELAY "$PROFILE" "$DEF_DPMS_DELAY")
SCREENSAVER=$(idle_profile_knob SCREENSAVER "$PROFILE" "$DEF_SCREENSAVER")
WARN_LEAD=$(idle_knob_uint KOOL_IDLE_WARN_LEAD 30)
DPMS_OFF=$(idle_knob_bool KOOL_IDLE_DPMS_OFF 1)
NAG=$(idle_knob_bool KOOL_IDLE_NAG 0)

# --- listener assembly ------------------------------------------------------
# Collected as TAB-separated records and emitted in ascending timeout order,
# so the generated file reads as a timeline.
LISTENERS=""
add_listener() { # timeout  comment  on-timeout  [on-resume]
    LISTENERS="${LISTENERS}${1}	${2}	${3}	${4-}
"
}

SD='$scriptsDir'
SCREEN_OFF="$SD/ScreenPower.sh off"
SCREEN_ON="$SD/ScreenPower.sh on"

if [ "$DPMS_OFF" = "1" ]; then
    # Manual lock (CTRL+ALT+L, SUPER+grave): timeouts count from the last input
    # event, which is the lock keypress itself.
    add_listener "$DPMS_DELAY" \
        "Manual lock, hyprlock: blank ${DPMS_DELAY}s after the lock keypress." \
        "pidof hyprlock && $SCREEN_OFF" \
        "pidof hyprlock && $SCREEN_ON"

    add_listener "$SCREENSAVER" \
        "Manual lock, screensaver: ${SCREENSAVER}s of animation, then blank." \
        "pidof swaylock-plugin && $SCREEN_OFF" \
        "pidof swaylock-plugin && $SCREEN_ON"
fi

if [ "$WARN_LEAD" -gt 0 ] && [ "$WARN_LEAD" -lt "$LOCK" ]; then
    warn_at=$(( LOCK - WARN_LEAD ))
    warn_msg="notify-send -a hypridle -t 5000 -e -i \$iDIR \" Locking in ${WARN_LEAD}s\""
    if [ "$NAG" = "1" ]; then
        warn_cmd="($SD/OnBattery.sh && $SD/IdleAlert.sh warn) & $warn_msg"
    else
        warn_cmd="$warn_msg"
    fi
    add_listener "$warn_at" \
        "Pre-lock warning, ${WARN_LEAD}s before the lock." \
        "$warn_cmd" \
        "notify-send -a hypridle -t 3000 -e -i \$iDIR \" Welcome back!\""
fi

add_listener "$LOCK" \
    "Auto-lock after ${LOCK}s of inactivity (${PROFILE_LABEL} profile)." \
    "loginctl lock-session"

if [ "$DPMS_OFF" = "1" ]; then
    # After an idle lock the clock keeps running from the last input event, so
    # these are lock + delay, not delay.
    add_listener "$(( LOCK + DPMS_DELAY ))" \
        "Idle lock, hyprlock: blank ${DPMS_DELAY}s after the lock fires." \
        "pidof swaylock-plugin || $SCREEN_OFF" \
        "$SCREEN_ON"

    add_listener "$(( LOCK + SCREENSAVER ))" \
        "Idle lock, screensaver: ${SCREENSAVER}s of animation, then blank." \
        "pidof swaylock-plugin && $SCREEN_OFF" \
        "pidof swaylock-plugin && $SCREEN_ON"
fi

# --- render -----------------------------------------------------------------
render() {
    cat <<EOF
# ==================================================
#  KoolDots (2026) -- GENERATED FILE, DO NOT EDIT
# ==================================================
# Written by scripts/GenerateHypridle.sh from
# UserConfigs/IdleSettings.conf. Any edit here is lost the next time the
# generator runs -- on upgrade, or when the charger is plugged or unplugged.
# Change the knobs in IdleSettings.conf instead, then:
#
#     ~/.config/hypr/scripts/GenerateHypridle.sh --restart
#
# Active profile: ${PROFILE_LABEL}
#
#   lock timeout        ${LOCK}s
#   warning lead        ${WARN_LEAD}s before the lock
#   blank delay         ${DPMS_DELAY}s after lock (hyprlock)
#   screensaver window  ${SCREENSAVER}s after lock (swaylock-plugin)
#   dpms-off            $([ "$DPMS_OFF" = 1 ] && echo enabled || echo "disabled (screens stay lit)")
#   nag/watchdog        $([ "$NAG" = 1 ] && echo enabled || echo disabled)
#
# Timeouts below are absolute seconds since the last input event, which is why
# the post-lock listeners read as lock + window.

\$iDIR = \$HOME/.config/swaync/images/ja.png
\$scriptsDir = \$HOME/.config/hypr/scripts

general {
EOF

    if [ "$NAG" = "1" ]; then
        cat <<EOF
    # Lock, and spawn the post-lock watchdog detached; it exits on unlock.
    # SwaylockScreensaver.sh runs swaylock-plugin with an xscreensaver hack
    # background (picker: SUPER SHIFT L) and execs hyprlock itself when the
    # package is absent; the || catches a swaylock-plugin that fails or is
    # killed, so a lock trigger can never leave the session unlocked.
    lock_cmd = (\$scriptsDir/SwaylockScreensaver.sh || hyprlock) & setsid -f \$scriptsDir/IdleWatchdog.sh
EOF
    else
        cat <<EOF
    # SwaylockScreensaver.sh runs swaylock-plugin with an xscreensaver hack
    # background (picker: SUPER SHIFT L) and execs hyprlock itself when the
    # package is absent; the || catches a swaylock-plugin that fails or is
    # killed, so a lock trigger can never leave the session unlocked.
    lock_cmd = \$scriptsDir/SwaylockScreensaver.sh || hyprlock
EOF
    fi

    cat <<EOF
    # Reap a locker that outlived its unlock. hyprlock can orphan itself after
    # a successful auth, and every dpms-off listener below is gated on
    # a "pidof" check for the locker -- a lingering process holds those gates
    # open, so the screen starts blanking a few seconds after you stop typing
    # while you are actively using the machine. Also resumes the screensaver,
    # so a hack stopped for a dark panel can never be left stopped.
    unlock_cmd = killall hyprlock; \$scriptsDir/ScreensaverPause.sh resume
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = \$scriptsDir/ScreenPower.sh on
    ignore_dbus_inhibit = false
}
EOF

    printf '%s' "$LISTENERS" | sort -n -t'	' -k1,1 | while IFS='	' read -r timeout comment on_timeout on_resume; do
        [ -n "$timeout" ] || continue
        printf '\n# %s\nlistener {\n    timeout = %s\n    on-timeout = %s\n' \
            "$comment" "$timeout" "$on_timeout"
        [ -n "$on_resume" ] && printf '    on-resume = %s\n' "$on_resume"
        printf '}\n'
    done
}

if [ "$TO_STDOUT" = "1" ]; then
    render
    exit 0
fi

tmp=$(mktemp "${OUTPUT}.XXXXXX") || exit 1
trap 'rm -f "$tmp"' EXIT
render >"$tmp" || exit 1
chmod 644 "$tmp"
mv -f "$tmp" "$OUTPUT"
trap - EXIT

if [ "$RESTART" = "1" ]; then
    "$SCRIPTS_DIR/Hypridle.sh" reload
fi

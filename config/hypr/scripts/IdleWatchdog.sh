#!/usr/bin/env bash
# Post-lock idle watchdog. Squawks every IDLE_WATCHDOG_INTERVAL seconds with
# escalating tiers until hyprlock exits. Spawned (detached) from hypridle's
# lock_cmd. Exits cleanly on unlock.
#
#   Squawk 1   -> gentle
#   Squawk 2   -> nag
#   Squawk 3+  -> dumbass

set -u

SCRIPTS_DIR="$HOME/.config/hypr/scripts"
IDLE_ALERT="$SCRIPTS_DIR/IdleAlert.sh"
ON_BATTERY="$SCRIPTS_DIR/OnBattery.sh"
CONF_FILE="${IDLE_ALERT_CONF:-$HOME/.config/hypr/idle-alert.conf}"

# shellcheck disable=SC1090
[[ -r "$CONF_FILE" ]] && source "$CONF_FILE"

INTERVAL="${IDLE_WATCHDOG_INTERVAL:-300}"
INTERVAL_DUMBASS="${IDLE_WATCHDOG_INTERVAL_DUMBASS:-60}"

# Screen-flash knobs (fires alongside each squawk while DPMS is off).
# Pattern: one long initial hold, then N accelerating follow-up pulses.
FLASH_ENABLED="${IDLE_WATCHDOG_FLASH:-true}"
FLASH_INITIAL_ON_SEC="${IDLE_WATCHDOG_FLASH_INITIAL_ON_SEC:-5.0}"
FLASH_PULSES="${IDLE_WATCHDOG_FLASH_PULSES:-5}"
FLASH_PULSE_START_SEC="${IDLE_WATCHDOG_FLASH_PULSE_START_SEC:-2.0}"
FLASH_PULSE_DECAY="${IDLE_WATCHDOG_FLASH_PULSE_DECAY:-0.25}"
FLASH_PULSE_OFF_SEC="${IDLE_WATCHDOG_FLASH_PULSE_OFF_SEC:-0.25}"
FLASH_PULSE_MIN_SEC="${IDLE_WATCHDOG_FLASH_PULSE_MIN_SEC:-0.1}"

# Single-instance guard: bail if another watchdog is already running.
self_pid=$$
if pgrep -f "[I]dleWatchdog\\.sh" | grep -vx "$self_pid" >/dev/null; then
    exit 0
fi

tier_for_squawk() {
    case "$1" in
        1) echo gentle ;;
        2) echo nag ;;
        *) echo dumbass ;;
    esac
}

interval_for_tier() {
    case "$1" in
        dumbass) echo "$INTERVAL_DUMBASS" ;;
        *) echo "$INTERVAL" ;;
    esac
}

flash_screen() {
    [[ "$FLASH_ENABLED" == "true" ]] || return 0

    # Initial long hold: screen stays on for FLASH_INITIAL_ON_SEC.
    hyprctl dispatch dpms on >/dev/null 2>&1 || return 0
    sleep "$FLASH_INITIAL_ON_SEC"
    hyprctl dispatch dpms off >/dev/null 2>&1 || return 0

    # Follow-up pulses: on-time shrinks by FLASH_PULSE_DECAY each iteration,
    # off-time between pulses stays fixed at FLASH_PULSE_OFF_SEC. No leading
    # off-gap before the first pulse -- the hold's dpms-off IS the boundary,
    # so the flicker fires the instant the screen drops.
    local dur="$FLASH_PULSE_START_SEC"
    local i
    for (( i = 0; i < FLASH_PULSES; i++ )); do
        hyprctl dispatch dpms on >/dev/null 2>&1 || return 0
        sleep "$dur"
        hyprctl dispatch dpms off >/dev/null 2>&1 || return 0
        (( i < FLASH_PULSES - 1 )) && sleep "$FLASH_PULSE_OFF_SEC"
        dur=$(awk -v d="$dur" -v f="$FLASH_PULSE_DECAY" -v m="$FLASH_PULSE_MIN_SEC" \
            'BEGIN { n = d * f; if (n < m) n = m; printf "%.4f", n }')
    done
}

n=1
while :; do
    tier=$(tier_for_squawk "$n")
    sleep "$(interval_for_tier "$tier")"
    pidof hyprlock >/dev/null 2>&1 || exit 0
    # Escalation tracks battery-drain time, not wall-clock time since lock:
    # AC-present intervals neither squawk nor advance the tier.
    if "$ON_BATTERY"; then
        flash_screen &
        "$IDLE_ALERT" "$tier" || true
        n=$(( n + 1 ))
    fi
done

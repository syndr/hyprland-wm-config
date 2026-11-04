#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Script for Monitor backlights (if supported) using brightnessctl
#
# Steps in raw hardware levels, never in percent, so a press is never a
# no-op on panels with few levels. Each press moves by KOOL_BRIGHTNESS_STEP
# percent of the range (default 3) or one hardware level, whichever is
# larger. Set it from UserConfigs/ENVariables.conf:
#   env = KOOL_BRIGHTNESS_STEP,5

iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/icons"
step_percent="${KOOL_BRIGHTNESS_STEP:-3}"

# Current raw level and max raw level, from `brightnessctl -m`
# (device,class,current,percent,max).
read_levels() {
    local line
    line=$(brightnessctl -m) || return 1
    current=$(cut -d, -f3 <<<"$line")
    max=$(cut -d, -f5 <<<"$line")
    [[ "$current" =~ ^[0-9]+$ && "$max" =~ ^[1-9][0-9]*$ ]]
}

to_percent() {
    echo $(( ($1 * 100 + max / 2) / max ))
}

# Get current brightness as an integer percent (without %)
get_brightness() {
    read_levels || return 1
    to_percent "$current"
}

# Determine the icon based on brightness level
get_icon_path() {
    local brightness=$1
    local level=$(( (brightness + 19) / 20 * 20 ))  # Round up to next 20
    if (( level > 100 )); then
        level=100
    fi
    echo "$iDIR/brightness-${level}.png"
}

# Send notification
send_notification() {
    local brightness=$1
    local icon_path=$2

    notify-send -e \
        -h string:x-canonical-private-synchronous:brightness_notif \
        -h int:value:"$brightness" \
        -u low \
        -i "$icon_path" \
        "Screen" "Brightness: ${brightness}%"
}

# Change brightness by one step in the given direction (+1 / -1) and notify
change_brightness() {
    local direction=$1
    local step new percent icon

    read_levels || return 1

    # Step in raw levels: step_percent of the range, at least one level.
    step=$(( (max * step_percent + 50) / 100 ))
    (( step < 1 )) && step=1

    new=$(( current + direction * step ))

    # Clamp to [1, max]: level 0 switches the backlight off.
    (( new < 1 )) && new=1
    (( new > max )) && new=$max

    brightnessctl set "$new"

    percent=$(to_percent "$new")
    icon=$(get_icon_path "$percent")
    send_notification "$percent" "$icon"
}

# Main
case "$1" in
    "--get")
        get_brightness
        ;;
    "--inc")
        change_brightness 1
        ;;
    "--dec")
        change_brightness -1
        ;;
    *)
        get_brightness
        ;;
esac

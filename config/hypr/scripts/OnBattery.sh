#!/usr/bin/env bash
# Exit 0 if the device is running on battery (no AC attached, or state unknown).
# Exit 1 if a Mains-type power supply is confirmed online.
#
# Fail-open on ambiguity: if we can't tell, assume battery so idle alerts still fire.

set -u

ac_found=0
for psy in /sys/class/power_supply/*/; do
    [[ -r "${psy}type" ]] || continue
    [[ "$(<"${psy}type")" == "Mains" ]] || continue
    ac_found=1
    [[ -r "${psy}online" ]] || continue
    if [[ "$(<"${psy}online")" == "1" ]]; then
        exit 1
    fi
done

if (( ac_found )); then
    exit 0
fi

# No Mains entry found — fall back to battery status heuristics.
for psy in /sys/class/power_supply/*/; do
    [[ -r "${psy}type" && -r "${psy}status" ]] || continue
    [[ "$(<"${psy}type")" == "Battery" ]] || continue
    case "$(<"${psy}status")" in
        Charging|Full|"Not charging") exit 1 ;;
    esac
done

exit 0

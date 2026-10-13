#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Exit 0 when a locker has been running for at least <seconds>; exit 1
# otherwise (including when nothing is locked).
#
# hypridle counts every timeout from the last input event, not from the lock,
# which makes "N seconds after the lock" impossible to express directly. The
# screensaver window therefore needs two listeners: one at N (a manual lock,
# where the keypress *is* the last activity) and one at lock+N (an idle lock).
# Both are gated on the locker running, so after an idle lock the first one
# also fires -- N seconds after the last activity, i.e. N-minus-lock seconds
# after the lock -- and blanks the screen early. With lock=900 and a 1200s
# window that cut the animation from 20 minutes to 5.
#
# Gating the manual-lock listener on the locker's own age fixes it: after a
# manual lock the locker is already N seconds old when the listener fires,
# while after an idle lock it is younger and the listener stays quiet, leaving
# the lock+N listener to do the job.
#
# Usage: LockerAge.sh <seconds> [locker ...]

set -u

min_age="${1:-0}"
case "$min_age" in ''|*[!0-9]*) exit 1 ;; esac
shift 2>/dev/null || true

lockers=("$@")
[ "${#lockers[@]}" -eq 0 ] && lockers=(swaylock-plugin hyprlock)

for pid in $(pidof "${lockers[@]}" 2>/dev/null); do
    # etimes is elapsed seconds since the process started.
    age=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
    case "$age" in ''|*[!0-9]*) continue ;; esac
    [ "$age" -ge "$min_age" ] && exit 0
done

exit 1

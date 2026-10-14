#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Rate-limit a scroll-wheel bind without letting the dropped events reach the
# focused window.
#
#   WheelThrottle.sh <name> <min_ms> <dispatcher> [args...]
#
# configs/Keybinds.conf sets binds:scroll_event_delay = 0 because Hyprland's
# own throttle passes every wheel event inside the delay window through to the
# window under the cursor (the page scrolls while a wheel chord is held). This
# wrapper gives an individual bind its own cadence instead: every event is
# still consumed by the bind, but the dispatcher only runs when at least
# <min_ms> have passed since the last time this <name> fired.

set -u

if [ $# -lt 3 ]; then
  echo "usage: ${0##*/} <name> <min_ms> <dispatcher> [args...]" >&2
  exit 2
fi

name="$1"
min_ms="$2"
shift 2

stamp="${XDG_RUNTIME_DIR:-/tmp}/hypr-wheel-${name//[^A-Za-z0-9_-]/_}"
now=$(date +%s%3N)
last=$(cat "$stamp" 2>/dev/null || echo 0)
case "$last" in
  '' | *[!0-9]*) last=0 ;;
esac

if [ $((now - last)) -lt "$min_ms" ]; then
  exit 0
fi

printf '%s' "$now" >"$stamp"
exec hyprctl dispatch "$@" >/dev/null

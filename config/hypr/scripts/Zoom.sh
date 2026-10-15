#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Step the desktop magnifier (cursor:zoom_factor) one notch in or out.
#
#   Zoom.sh in|out|reset [step]
#
# Hyprland fires a wheel bind once per wheel event and does not expose the
# event's magnitude, so the step is applied per event. A hi-res wheel (or the
# trackball-scroll daemon) delivers many events per physical notch, which is
# why the default step is small. Override with the second argument or
# KOOL_ZOOM_STEP. Zooming out is clamped to exactly 1.0 (real size); zooming
# in is capped at KOOL_ZOOM_MAX.

set -u

STEP="${2:-${KOOL_ZOOM_STEP:-1.05}}"
MIN=1.0
MAX="${KOOL_ZOOM_MAX:-8.0}"

case "${1:-}" in
  in | out) ;;
  reset)
    hyprctl keyword cursor:zoom_factor 1.0 >/dev/null
    exit 0
    ;;
  *)
    echo "usage: ${0##*/} in|out|reset [step]" >&2
    exit 2
    ;;
esac

current=$(hyprctl -j getoption cursor:zoom_factor 2>/dev/null | jq -r '.float // empty' 2>/dev/null)
case "$current" in
  '' | *[!0-9.]*) current=1.0 ;;
esac

new=$(awk -v cur="$current" -v step="$STEP" -v dir="$1" -v min="$MIN" -v max="$MAX" 'BEGIN {
  if (cur < min) cur = min
  v = (dir == "in") ? cur * step : cur / step
  if (v < min) v = min
  if (v > max) v = max
  printf "%.4f", v
}')

hyprctl keyword cursor:zoom_factor "$new" >/dev/null

#!/usr/bin/env bash
# Cycle orientation - works with master and nstack layouts
# Usage: ChangeOrientation.sh [next|prev]

DIRECTION=${1:-next}

if [[ "$DIRECTION" == "next" ]]; then
  hyprctl dispatch layoutmsg orientationnext
else
  hyprctl dispatch layoutmsg orientationprev
fi

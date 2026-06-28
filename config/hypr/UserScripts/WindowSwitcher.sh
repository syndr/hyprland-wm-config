#!/usr/bin/env bash
# Filtered rofi window switcher.
# rofi's built-in window modi lists every toplevel Hyprland exports, including
# windows parked on special workspaces (dropdown terminal scratchpad,
# xwaylandvideobridge, etc.). This lists only normal-workspace windows,
# most-recently-focused first, and focuses the selection.

selection=$(hyprctl clients -j | jq -r '
  [ .[]
    | select(.mapped)
    | select(.workspace.name | startswith("special:") | not)
  ]
  | sort_by(.focusHistoryID)
  | .[]
  | "\(.address)\t\(.class)\t[\(.workspace.name)] \(.title)"' |
  rofi -dmenu -i -p "window" \
    -display-columns 2,3 -display-column-separator "\t")

addr="${selection%%$'\t'*}"
[ -n "$addr" ] && hyprctl dispatch focuswindow "address:$addr"
